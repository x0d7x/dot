-- research.lua: mark locations while reading unfamiliar code, keep notes
-- per repo under ~/my-research/<remote>/research-<seq>.md, and flag marks
-- whose captured lines have changed since (content-hash based, so a dirty
-- working tree elsewhere in the file never causes a false positive).

_G.research = _G.research or {}
local research = _G.research

local store = {}
local capture = {}
local nav = {}
local stale = {}
local render = {}
local annotate = {}
local active = {} -- [repo_root] = { topic = "...", path = "..." }
local view_buffers = {} -- [path] = bufnr of the rendered (readonly) view buffer for that path
local view_state = {} -- [bufnr] = { path = "...", marks = { {...}, ... } } for the view buffer
local last_file_win = {} -- [tabpage] = last window focused on a real project file
local win_tracking_armed = false -- WinEnter tracker armed lazily

-- pcall wrapper: one notify instead of a raw traceback.
local function guarded(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			vim.notify("research: internal error: " .. tostring(err), vim.log.levels.ERROR)
		end
	end
end

-- skips registration when lhs is nil/"" (config.keymap opt-out).
local function safe_keymap(mode, lhs, rhs, opts)
	if not lhs or lhs == "" then
		return
	end
	vim.keymap.set(mode, lhs, rhs, opts)
end

-- a fake-path scratch buffer name is still a path to :e: with no BufReadCmd,
-- plain :e wipes it empty and flips buftype real, letting autowrite later
-- create it on disk for real. This makes :e a no-op instead.
local function block_reload(buf)
	vim.api.nvim_create_autocmd("BufReadCmd", {
		buffer = buf,
		callback = function() end,
	})
end

-- groups live keymaps by desc prefix ("research: " local, "Research: " global).
local function collect_keymaps(desc_prefix, maps_list)
	local seen = {}
	local out = {}
	for _, maps in ipairs(maps_list) do
		for _, m in ipairs(maps) do
			if m.desc and m.lhs and m.desc:sub(1, #desc_prefix) == desc_prefix and not seen[m.lhs] then
				seen[m.lhs] = true
				table.insert(out, { lhs = m.lhs, desc = m.desc:sub(#desc_prefix + 1) })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.desc < b.desc
	end)
	return out
end

-- lhs is already resolved to raw keys; <leader>/<localleader> are pure
-- :map-time substitution and aren't stored anywhere, so reconstruct them.
local function display_lhs(lhs)
	local leader = vim.g.mapleader
	if leader and leader ~= "" and lhs:sub(1, #leader) == leader then
		return "<leader>" .. lhs:sub(#leader + 1)
	end
	local localleader = vim.g.maplocalleader
	if localleader and localleader ~= "" and lhs:sub(1, #localleader) == localleader then
		return "<localleader>" .. lhs:sub(#localleader + 1)
	end
	return lhs
end

-- introspects live keymaps (desc-prefix filtered) instead of a hand-kept list.
local function show_keymap_help()
	local buf_local = collect_keymaps("research: ", { vim.api.nvim_buf_get_keymap(0, "n") })
	local global = collect_keymaps("Research: ", { vim.api.nvim_get_keymap("n"), vim.api.nvim_get_keymap("v") })

	local lines = { "Buffer-local (this buffer)", "" }
	for _, e in ipairs(buf_local) do
		table.insert(lines, string.format("  %-16s %s", display_lhs(e.lhs), e.desc))
	end
	table.insert(lines, "")
	table.insert(lines, "Global (works anywhere)")
	table.insert(lines, "")
	for _, e in ipairs(global) do
		table.insert(lines, string.format("  %-16s %s", display_lhs(e.lhs), e.desc))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local width = 20
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width + 2, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 6)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " research keymaps (q to close) ",
		title_pos = "center",
	})
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", guarded(close), { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", guarded(close), { buffer = buf, silent = true })
end

;(function --[[config]]()
	research.config = {
		research_dir = "~/my-research",
		context_lines = 4, -- extra lines captured below the cursor when not in visual mode
		trim_indent = true, -- strip the snippet's common leading indentation when capturing
		preview_jump = false, -- move focus into the preview window instead of staying put
		-- size: 0.1-1.0 ratio of columns/lines, or "content" to fit exactly
		-- (float: true=fit content, false=use max). min/max clamp the result.
		preview = {
			split = { height = "content", min = 0.1, max = 0.5 },
			vsplit = { width = "content", min = 0.1, max = 0.5 },
			float = { width = true, height = true, min = 0.1, max = 0.5 },
		},
		split = "vertical", -- "vertical" | "horizontal"
		keymap = {
			jump = "<S-CR>", -- jump to the mark's source, moving focus there
			peek = "<CR>", -- show the mark's source, keeping focus here
			toggle = "<leader>e", -- raw research buffer: switch to view. view buffer: edit the mark under cursor (title/note/snippet)
			delete = "dd", -- delete the mark under cursor (view mode only, with confirmation)
			move_up = "[e", -- swap the mark under cursor with the one above (view mode only)
			move_down = "]e", -- swap the mark under cursor with the one below (view mode only)
			sync = "<leader>S", -- resync the mark under cursor (view mode only)
			snippet = "<leader>s", -- pop up the mark's stored snippet (view mode only)
			yank = "<leader>ry", -- copy the mark's "file:line_start" to the system clipboard
			help = "?", -- show buffer-local + global research keymaps in a popup
			toggle_snippet = "<leader>rt", -- show/hide the mark's snippet inline (flips its stored selection field)
			mark_preview = "<leader>rp", -- preview the mark under cursor in a floating window (project file buffers only)
			mark_preview_new = "<leader>rP", -- ...forcing a new floating window instead of reusing one
			mark_preview_split = "<leader>rh", -- preview the mark under cursor in a horizontal split
			mark_preview_split_new = "<leader>rH", -- ...forcing a new split instead of reusing one
			mark_preview_vsplit = "<leader>rv", -- preview the mark under cursor in a vertical split
			mark_preview_vsplit_new = "<leader>rV", -- ...forcing a new vsplit instead of reusing one
			mark_goto = "<leader>rg", -- jump to the mark under cursor in its research view (project file buffers only)
		},
		icons = {
			stale = "🚩", -- sign shown when the captured content has changed
			missing = "✗", -- sign shown when the source file no longer exists
			annotated = "🔖", -- sign shown in a source buffer on a line with a research mark
		},
		icon_virt_text_pos = "eol", -- see :h nvim_buf_set_extmark's virt_text_pos
		annotate_enabled = true, -- show research.config.icons.annotated on marked lines in source buffers
		annotate_sync_on_save = true, -- hand-edited :w on a research file also refreshes open source buffers' icons
		annotate_auto_resync = true, -- saving a source file auto-relocates any marks that shifted or moved
	}
end)()

;(function --[[store]]()
	store.ERR_MARK_MOVED = "the marked lines changed directly — git can't remap this, try exact search"

	-- pcall: missing git binary degrades gracefully instead of throwing.
	function store.safe_git(args)
		local ok, out = pcall(vim.fn.systemlist, args)
		if not ok then
			return {}, false
		end
		return out, vim.v.shell_error == 0
	end

	function store.safe_readfile(path, ...)
		local ok, out = pcall(vim.fn.readfile, path, ...)
		if not ok then
			return nil
		end
		return out
	end

	function store.safe_writefile(lines, path)
		local ok, result = pcall(vim.fn.writefile, lines, path)
		if not ok or result == -1 then
			vim.notify("research: failed to write " .. path, vim.log.levels.ERROR)
			return false
		end
		return true
	end

	-- git repo root, else cwd. staleness is hash-based and works either way;
	-- only commit tracking and git-offset resync need a real git repo.
	function store.repo_root(path)
		local dir = vim.fn.fnamemodify(path, ":p:h")
		local out, ok = store.safe_git({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
		if ok and #out > 0 then
			return vim.trim(out[1])
		end
		return vim.fn.getcwd()
	end

	-- arms WinEnter tracking lazily, once, on first use.
	function store.ensure_win_tracking()
		if win_tracking_armed then
			return
		end
		win_tracking_armed = true
		vim.api.nvim_create_autocmd("WinEnter", {
			callback = guarded(function()
				local win = vim.api.nvim_get_current_win()
				-- deferred: :vnew/:new briefly shows the old buffer before our swap.
				vim.schedule(guarded(function()
					if not vim.api.nvim_win_is_valid(win) then
						return
					end
					local buf = vim.api.nvim_win_get_buf(win)
					if store.is_project_file_buf(buf) then
						last_file_win[vim.api.nvim_get_current_tabpage()] = win
					end
				end))
			end),
		})
	end

	local function remote_slug(root)
		local out, ok = store.safe_git({ "git", "-C", root, "config", "--get", "remote.origin.url" })
		if not ok or #out == 0 or vim.trim(out[1]) == "" then
			return nil
		end
		local url = vim.trim(out[1])
		url = url:gsub("^git@", "")
		url = url:gsub("^ssh://git@", "")
		url = url:gsub("^https?://", "")
		url = url:gsub(":", "/")
		url = url:gsub("%.git$", "")
		url = url:gsub("^/+", "")
		url = url:gsub("/+", "_")
		return url
	end

	local function fallback_slug(root)
		local base = vim.fn.fnamemodify(root, ":t")
		return base .. "_" .. vim.fn.sha256(root):sub(1, 8)
	end

	local function titlecase(s)
		return (s:gsub("(%a)([%w']*)", function(first, rest)
			return first:upper() .. rest:lower()
		end))
	end

	function store.home_relative(path)
		local home = vim.fn.expand("~")
		if path:sub(1, #home) == home then
			return "~" .. path:sub(#home + 1)
		end
		return path
	end

	function store.research_dir(root)
		local slug = remote_slug(root) or fallback_slug(root)
		return vim.fn.expand(research.config.research_dir) .. "/" .. slug
	end

	function store.list_files(dir)
		return vim.fn.glob(dir .. "/research-*.md", false, true)
	end

	local function next_seq(dir)
		local max = 0
		for _, f in ipairs(store.list_files(dir)) do
			local n = tonumber(f:match("research%-(%d+)%.md$"))
			if n and n > max then
				max = n
			end
		end
		return max + 1
	end

	function store.parse_frontmatter(path)
		if vim.fn.filereadable(path) == 0 then
			return nil
		end
		local lines = store.safe_readfile(path, "", 20)
		if not lines or lines[1] ~= "---" then
			return nil
		end
		local fm = {}
		for i = 2, #lines do
			if lines[i] == "---" then
				break
			end
			local k, v = lines[i]:match("^([%w_]+):%s*(.*)$")
			if k then
				fm[k] = v
			end
		end
		return fm
	end

	function store.find_topic_file(dir, topic)
		for _, f in ipairs(store.list_files(dir)) do
			local fm = store.parse_frontmatter(f)
			if fm and fm.title and fm.title:lower() == topic:lower() then
				return f
			end
		end
		return nil
	end

	function store.create_file(root, topic)
		local dir = store.research_dir(root)
		vim.fn.mkdir(dir, "p")
		local seq = next_seq(dir)
		local path = dir .. "/research-" .. seq .. ".md"
		local created = os.date("%Y-%m-%d")
		local lines = {
			"---",
			"title: " .. topic,
			"repo_remote: " .. (remote_slug(root) or ""),
			"repo_path: " .. store.home_relative(root),
			"created: " .. created,
			"---",
			"",
			"# " .. titlecase(topic) .. " | " .. created,
			"",
		}
		if not store.safe_writefile(lines, path) then
			return nil
		end
		return path
	end

	function store.find_or_create_file(root, topic)
		return store.find_topic_file(store.research_dir(root), topic) or store.create_file(root, topic)
	end

	-- true on success; false with a notify already shown on failure.
	function store.append_entry(path, entry_lines)
		local lines = store.safe_readfile(path)
		if not lines then
			vim.notify("research: could not read " .. path, vim.log.levels.ERROR)
			return false
		end
		while #lines > 0 and vim.trim(lines[#lines]) == "" do
			table.remove(lines)
		end
		local has_marks = false
		for _, l in ipairs(lines) do
			if l:match("^### ") then
				has_marks = true
				break
			end
		end
		table.insert(lines, "")
		if has_marks then
			table.insert(lines, "---")
			table.insert(lines, "")
		end
		for _, l in ipairs(entry_lines) do
			table.insert(lines, l)
		end
		table.insert(lines, "")
		local ok = store.safe_writefile(lines, path)
		if ok then
			annotate.invalidate()
			annotate.sync_open_buffers()
		end
		return ok
	end

	-- { header, blocks }; delete/reorder just splice blocks, write_blocks() rejoins.
	function store.parse_blocks(path)
		local lines = store.safe_readfile(path)
		if not lines then
			return {}, {}
		end
		local header = {}
		local blocks = {}
		local i = 1
		while i <= #lines and not lines[i]:match("^### ") do
			table.insert(header, lines[i])
			i = i + 1
		end
		while #header > 0 and vim.trim(header[#header]) == "" do
			table.remove(header)
		end

		while i <= #lines do
			local block_lines = {}
			local in_fence = false
			while i <= #lines do
				local l = lines[i]
				if not in_fence and (l == "---" or (l:match("^##+ ") and #block_lines > 0)) then
					break
				end
				if l:match("^```") then
					in_fence = not in_fence
				end
				table.insert(block_lines, l)
				i = i + 1
			end
			while #block_lines > 0 and vim.trim(block_lines[#block_lines]) == "" do
				table.remove(block_lines)
			end
			local block = { lines = block_lines }
			for _, l in ipairs(block_lines) do
				local k, v = l:match("^([%w_]+):%s*(.*)$")
				if k == "file" or k == "line_start" or k == "line_end" or k == "commit" or k == "hash" then
					block[k] = v
				end
			end
			table.insert(blocks, block)
			while i <= #lines and (lines[i] == "---" or vim.trim(lines[i]) == "") do
				i = i + 1
			end
		end

		return header, blocks
	end

	-- true on success; false with a notify already shown on failure.
	function store.write_blocks(path, header, blocks)
		local lines = {}
		vim.list_extend(lines, header)
		for idx, b in ipairs(blocks) do
			table.insert(lines, "")
			if idx > 1 then
				table.insert(lines, "---")
				table.insert(lines, "")
			end
			vim.list_extend(lines, b.lines)
		end
		table.insert(lines, "")
		local ok = store.safe_writefile(lines, path)
		if ok then
			annotate.invalidate()
			annotate.sync_open_buffers()
		end
		return ok
	end

	-- line shift since mk.commit from hunks outside the marked range; nil+reason
	-- if the range itself was touched, there's no commit, or git failed.
	function store.git_offset(root, mk)
		if not mk.commit or mk.commit == "" then
			return nil, "no commit recorded for this mark"
		end
		local line_start = tonumber(mk.line_start)
		local line_end = tonumber(mk.line_end)
		if not line_start or not line_end then
			return nil, "malformed line numbers"
		end
		-- -w: a reindent alone shouldn't register as "marked lines changed directly".
		local diff, ok = store.safe_git({ "git", "-C", root, "diff", "-w", mk.commit, "--", mk.file })
		if not ok then
			return nil, "git diff failed (commit may be unreachable)"
		end
		local offset = 0
		for _, l in ipairs(diff) do
			local a, blen, _, dlen = l:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
			if a then
				a = tonumber(a)
				blen = blen ~= "" and tonumber(blen) or 1
				dlen = dlen ~= "" and tonumber(dlen) or 1
				local old_last = blen == 0 and a or (a + blen - 1)
				if old_last >= line_start and a <= line_end then
					return nil, store.ERR_MARK_MOVED
				elseif old_last < line_start then
					offset = offset + (dlen - blen)
				end
			end
		end
		return offset
	end

	function store.extract_snippet(block_lines)
		local snippet = {}
		local in_fence = false
		for _, l in ipairs(block_lines) do
			if l:match("^```") then
				if in_fence then
					break
				end
				in_fence = true
			elseif in_fence then
				table.insert(snippet, l)
			end
		end
		return snippet
	end

	-- trims each line so a pure reindent never counts as a content change.
	function store.normalize_snippet(lines)
		local out = {}
		for i, l in ipairs(lines) do
			out[i] = vim.trim(l)
		end
		return out
	end

	function store.snippet_hash(lines)
		return vim.fn.sha256(table.concat(store.normalize_snippet(lines), "\n"))
	end

	-- 1-indexed match lines, whitespace-insensitive.
	function store.find_snippet(abspath, snippet)
		if #snippet == 0 then
			return {}
		end
		local lines = store.safe_readfile(abspath)
		if not lines then
			return {}
		end
		local target = store.normalize_snippet(snippet)
		local matches = {}
		for i = 1, #lines - #target + 1 do
			local ok = true
			for j = 1, #target do
				if vim.trim(lines[i + j - 1]) ~= target[j] then
					ok = false
					break
				end
			end
			if ok then
				table.insert(matches, i)
			end
		end
		return matches
	end

	-- replaces "key: value", or inserts it before "-->" if the block predates it.
	local function set_field(lines, key, value)
		for i, l in ipairs(lines) do
			if l:match("^" .. key .. ":") then
				lines[i] = key .. ": " .. value
				return
			end
		end
		for i, l in ipairs(lines) do
			if l:match("^%-%->") then
				table.insert(lines, i, key .. ": " .. value)
				return
			end
		end
	end
	store.set_field = set_field

	-- re-points a mark at new location/snippet, keeping its heading/note.
	function store.replace_block_snippet(block, fields, ft, snippet)
		set_field(block.lines, "file", fields.file)
		set_field(block.lines, "line_start", tostring(fields.line_start))
		set_field(block.lines, "line_end", tostring(fields.line_end))
		set_field(block.lines, "commit", fields.commit)
		set_field(block.lines, "hash", fields.hash)
		set_field(block.lines, "selection", tostring(fields.selection))

		local close_idx = nil
		for i, l in ipairs(block.lines) do
			if l:match("^%-%->") then
				close_idx = i
				break
			end
		end
		local fence_start = nil
		if close_idx then
			for i = close_idx + 1, #block.lines do
				if block.lines[i]:match("^```") then
					fence_start = i
					break
				end
			end
		end
		local fence_end = nil
		if fence_start then
			local scan = fence_start + 1
			while scan <= #block.lines and not block.lines[scan]:match("^```") do
				scan = scan + 1
			end
			if scan <= #block.lines then
				fence_end = scan -- an actual closing fence was found, not just end-of-block
			end
		end

		local new_fence = { "```" .. ft }
		vim.list_extend(new_fence, snippet)
		table.insert(new_fence, "```")

		if fence_start and fence_end then
			for _ = fence_start, fence_end do
				table.remove(block.lines, fence_start)
			end
			for i, l in ipairs(new_fence) do
				table.insert(block.lines, fence_start + i - 1, l)
			end
		else
			-- no existing fence (shouldn't happen) — add one after the metadata comment.
			local insert_at = (close_idx or #block.lines) + 1
			for i, l in ipairs(new_fence) do
				table.insert(block.lines, insert_at + i - 1, l)
			end
		end
	end

	-- "git" (offset-only) or "search" (exact match) relocate; nothing written
	-- on failure. opts.require_unique fails on an ambiguous match instead of
	-- guessing (auto-resync sets it, manual sync doesn't).
	function store.resync_mark(path, root, mk, mode, opts)
		local header, blocks = store.parse_blocks(path)
		local idx = nil
		for i, b in ipairs(blocks) do
			if
				b.file == mk.file
				and b.line_start == mk.line_start
				and b.line_end == mk.line_end
				and b.commit == mk.commit
			then
				idx = i
				break
			end
		end
		if not idx then
			return false, "could not locate mark in storage"
		end
		local block = blocks[idx]
		local abspath = root .. "/" .. block.file
		if vim.fn.filereadable(abspath) == 0 then
			return false, "source file missing: " .. block.file
		end

		local new_start, new_end
		if mode == "git" then
			local offset, err = store.git_offset(root, block)
			if not offset then
				return false, err or "git sync unavailable"
			end
			if offset == 0 then
				return false, "already in sync"
			end
			new_start = tonumber(block.line_start) + offset
			new_end = tonumber(block.line_end) + offset
		else
			local snippet = store.extract_snippet(block.lines)
			local matches = store.find_snippet(abspath, snippet)
			if #matches == 0 then
				return false, "exact snippet not found in current file — still flagged stale"
			end
			if opts and opts.require_unique and #matches > 1 then
				return false,
					string.format(
						"snippet matches %d locations — ambiguous, resolve with :ResearchMarkSync",
						#matches
					)
			end
			local orig = tonumber(block.line_start) or 0
			table.sort(matches, function(a, b)
				return math.abs(a - orig) < math.abs(b - orig)
			end)
			new_start = matches[1]
			new_end = new_start + #snippet - 1
			if new_start == orig then
				return false, "already in sync"
			end
		end

		local commit = ""
		local out, ok = store.safe_git({ "git", "-C", root, "rev-parse", "--short", "HEAD" })
		if ok and out[1] then
			commit = vim.trim(out[1])
		end

		local cur_lines = store.safe_readfile(abspath, "", new_end) or {}
		local new_snippet = {}
		for i = new_start, math.min(new_end, #cur_lines) do
			table.insert(new_snippet, cur_lines[i])
		end

		set_field(block.lines, "line_start", tostring(new_start))
		set_field(block.lines, "line_end", tostring(new_end))
		set_field(block.lines, "commit", commit)
		set_field(block.lines, "hash", store.snippet_hash(new_snippet))

		if not store.write_blocks(path, header, blocks) then
			return false, "failed to write research file"
		end
		return true, string.format("synced to %s:%d-%d", block.file, new_start, new_end)
	end

	function store.is_project_file_buf(buf)
		if vim.bo[buf].buftype ~= "" then
			return false
		end
		local name = vim.api.nvim_buf_get_name(buf)
		if name == "" then
			return false
		end
		if name:match("^research%-view://") or name:match("^research://") then
			return false
		end
		local research_dir = vim.fn.expand(research.config.research_dir)
		if name:sub(1, #research_dir) == research_dir then
			return false
		end
		return true
	end

	-- keep_focus makes it a peek instead of a jump.
	function store.jump_to_source(abspath, line, keep_focus)
		local origin_win = vim.api.nvim_get_current_win()
		local tab = vim.api.nvim_get_current_tabpage()
		local win = last_file_win[tab]
		if not win or not vim.api.nvim_win_is_valid(win) then
			-- no tracked window (e.g. the first window never fires WinEnter) — fall back.
			for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				if store.is_project_file_buf(vim.api.nvim_win_get_buf(w)) then
					win = w
					break
				end
			end
		end
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
		else
			vim.cmd(research.config.split == "horizontal" and "split" or "vsplit")
			win = vim.api.nvim_get_current_win()
			-- split copies window-local opts; a 'winfixbuf' source window would block :edit below.
			vim.wo[win].winfixbuf = false
		end
		vim.cmd("edit " .. vim.fn.fnameescape(abspath))
		vim.api.nvim_win_set_cursor(0, { line, 0 })
		last_file_win[tab] = win
		if keep_focus and vim.api.nvim_win_is_valid(origin_win) then
			vim.api.nvim_set_current_win(origin_win)
		end
	end
end)()

;(function --[[capture]]()
	local function context_range(bufnr, line)
		local ctx = math.max(research.config.context_lines or 1, 1)
		local last = vim.api.nvim_buf_line_count(bufnr)
		return line, math.min(line + ctx, last)
	end

	-- strips common leading indent so a nested snippet reads as top-level.
	-- display-only: staleness/resync trim per-line anyway, unaffected.
	local function dedent(lines)
		local min_len = nil
		for _, l in ipairs(lines) do
			if vim.trim(l) ~= "" then
				local ws_len = #l:match("^%s*")
				if not min_len or ws_len < min_len then
					min_len = ws_len
				end
			end
		end
		if not min_len or min_len == 0 then
			return lines
		end
		local out = {}
		for i, l in ipairs(lines) do
			local ws_len = #l:match("^%s*")
			out[i] = l:sub(math.min(min_len, ws_len) + 1)
		end
		return out
	end

	local function open_note_buffer(on_save)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].filetype = "markdown"
		vim.bo[buf].buftype = "acwrite"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
		vim.api.nvim_buf_set_name(buf, string.format("research:note-%d", buf))
		block_reload(buf)
		local width = math.floor(vim.o.columns * 0.6)
		local height = 10
		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
			style = "minimal",
			border = "rounded",
			title = " research mark: 1st line = name, rest = note (:w save, :q cancel) ",
			title_pos = "center",
		})
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = buf,
			once = true,
			callback = guarded(function()
				local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				while #lines > 0 and vim.trim(lines[#lines]) == "" do
					table.remove(lines)
				end
				while #lines > 0 and vim.trim(lines[1]) == "" do
					table.remove(lines, 1)
				end
				vim.bo[buf].modified = false
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
				on_save(lines)
			end),
		})
		vim.cmd.startinsert()
	end

	-- nil + a ready-to-notify reason on failure.
	local function capture_payload(is_range, line1, line2)
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		if filepath == "" then
			return nil, "research: buffer has no file"
		end
		local root = store.repo_root(filepath)
		if not root then
			return nil, "research: could not determine a project root"
		end

		local start_line, end_line
		if is_range then
			start_line, end_line = line1, line2
		else
			start_line, end_line = context_range(bufnr, vim.fn.line("."))
		end

		local snippet = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
		if research.config.trim_indent then
			snippet = dedent(snippet)
		end
		local relfile = filepath:sub(#root + 2)
		local commit = ""
		local out, ok = store.safe_git({ "git", "-C", root, "rev-parse", "--short", "HEAD" })
		if ok and out[1] then
			commit = vim.trim(out[1])
		end

		return {
			root = root,
			is_range = is_range,
			start_line = start_line,
			end_line = end_line,
			snippet = snippet,
			relfile = relfile,
			commit = commit,
			hash = store.snippet_hash(snippet),
			ft = vim.bo[bufnr].filetype or "",
		}
	end

	local function refresh_open_view(path)
		local view_buf = view_buffers[path]
		if view_buf and vim.api.nvim_buf_is_valid(view_buf) then
			for _, w in ipairs(vim.fn.win_findbuf(view_buf)) do
				render.open(path, w)
			end
		end
	end
	store.refresh_open_view = refresh_open_view

	local function set_active(root, topic_name, path)
		if not path then
			vim.notify("research: failed to create research file for '" .. topic_name .. "'", vim.log.levels.ERROR)
			return
		end
		active[root] = { topic = topic_name, path = path }
		vim.notify("research: active topic '" .. topic_name .. "' -> " .. path)
	end

	local function prompt_new(root, on_created)
		vim.ui.input({ prompt = "New research topic name: " }, guarded(function(input)
			input = vim.trim(input or "")
			if input == "" then
				vim.notify("research: cancelled", vim.log.levels.WARN)
				return
			end
			local path = store.find_or_create_file(root, input)
			set_active(root, input, path)
			if path and on_created then
				on_created(path)
			end
		end))
	end

	local function save_mark(payload, path)
		open_note_buffer(function(note_lines)
			local name = vim.trim(note_lines[1] or "")
			if name == "" then
				name = payload.relfile .. ":" .. payload.start_line
			end
			local body = {}
			for i = 2, #note_lines do
				table.insert(body, note_lines[i])
			end
			while #body > 0 and vim.trim(body[1]) == "" do
				table.remove(body, 1)
			end
			while #body > 0 and vim.trim(body[#body]) == "" do
				table.remove(body)
			end

			local entry = {}
			table.insert(entry, "### " .. name .. " | " .. os.date("%Y-%m-%d"))
			table.insert(entry, "<!-- research-mark")
			table.insert(entry, "file: " .. payload.relfile)
			table.insert(entry, "line_start: " .. payload.start_line)
			table.insert(entry, "line_end: " .. payload.end_line)
			table.insert(entry, "commit: " .. payload.commit)
			table.insert(entry, "hash: " .. payload.hash)
			table.insert(entry, "selection: " .. tostring(payload.is_range))
			table.insert(entry, "-->")
			table.insert(entry, "```" .. payload.ft)
			vim.list_extend(entry, payload.snippet)
			table.insert(entry, "```")
			if #body > 0 then
				table.insert(entry, "")
				vim.list_extend(entry, body)
			end

			if not store.append_entry(path, entry) then
				return
			end
			vim.notify("research: mark '" .. name .. "' saved to " .. path)
			refresh_open_view(path)
		end)
	end

	-- always asks which topic to add the mark to (creating one if none yet).
	function capture.mark(is_range, line1, line2)
		local payload, err = capture_payload(is_range, line1, line2)
		if not payload then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end

		local files = store.list_files(store.research_dir(payload.root))
		if #files == 0 then
			prompt_new(payload.root, function(path)
				save_mark(payload, path)
			end)
			return
		end

		local items = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(items, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end
		table.insert(items, { new = true, title = "+ new topic..." })
		vim.ui.select(items, {
			prompt = "Add mark to which research topic?",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(choice)
			if not choice then
				return
			end
			if choice.new then
				prompt_new(payload.root, function(path)
					save_mark(payload, path)
				end)
				return
			end
			active[payload.root] = { topic = choice.title, path = choice.path }
			save_mark(payload, choice.path)
		end))
	end

	-- adds to the active topic directly; falls back to capture.mark's picker if none set.
	function capture.mark_active(is_range, line1, line2)
		local payload, err = capture_payload(is_range, line1, line2)
		if not payload then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end
		local act = active[payload.root]
		if not act then
			capture.mark(is_range, line1, line2)
			return
		end
		save_mark(payload, act.path)
	end

	-- a Lua-callback visual keymap runs before '<,'> refreshes, so those marks
	-- can be stale/unset (neovim/neovim#18340); getpos(".")/getpos("v") are
	-- live in visual mode, so use those instead.
	local function resolve_selection()
		local mode = vim.api.nvim_get_mode().mode
		if mode == "v" or mode == "V" or mode == "\22" then
			local cursor_line = vim.fn.getpos(".")[2]
			local anchor_line = vim.fn.getpos("v")[2]
			return true, math.min(cursor_line, anchor_line), math.max(cursor_line, anchor_line)
		end
		local line = vim.fn.line(".")
		return false, line, line
	end

	function capture.mark_selection()
		capture.mark(resolve_selection())
	end

	function capture.mark_selection_active()
		capture.mark_active(resolve_selection())
	end

	function capture.resnippet_selection()
		capture.resnippet(resolve_selection())
	end

	-- for when the content is gone for good, not just shifted (see resync_mark).
	function capture.resnippet(is_range, line1, line2)
		local payload, err = capture_payload(is_range, line1, line2)
		if not payload then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end

		local files = store.list_files(store.research_dir(payload.root))
		if #files == 0 then
			vim.notify("research: no research files yet for this repo", vim.log.levels.ERROR)
			return
		end

		local topics = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(topics, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end

		vim.ui.select(topics, {
			prompt = "Update a mark in which research topic?",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(topic)
			if not topic then
				return
			end
			local header, blocks = store.parse_blocks(topic.path)
			if #blocks == 0 then
				vim.notify("research: no marks yet in " .. topic.path, vim.log.levels.WARN)
				return
			end

			local items = {}
			for i, b in ipairs(blocks) do
				local name = (b.lines[1] or ""):gsub("^###%s*", "")
				table.insert(items, { idx = i, label = name ~= "" and name or ("mark " .. i) })
			end

			vim.ui.select(items, {
				prompt = "Update which mark's snippet?",
				format_item = function(item)
					return item.label
				end,
			}, guarded(function(choice)
				if not choice then
					return
				end
				store.replace_block_snippet(blocks[choice.idx], {
					file = payload.relfile,
					line_start = payload.start_line,
					line_end = payload.end_line,
					commit = payload.commit,
					hash = payload.hash,
					selection = payload.is_range,
				}, payload.ft, payload.snippet)
				if not store.write_blocks(topic.path, header, blocks) then
					return
				end
				active[payload.root] = { topic = topic.title, path = topic.path }
				vim.notify("research: updated snippet for '" .. choice.label .. "'")
				refresh_open_view(topic.path)
			end))
		end))
	end

	function capture.start(topic)
		topic = vim.trim(topic or "")
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			vim.notify("research: could not determine a project root", vim.log.levels.ERROR)
			return
		end

		if topic ~= "" then
			set_active(root, topic, store.find_or_create_file(root, topic))
			return
		end

		local files = store.list_files(store.research_dir(root))
		if #files == 0 then
			prompt_new(root)
			return
		end

		local items = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(items, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end
		table.insert(items, { new = true, title = "+ new topic..." })
		vim.ui.select(items, {
			prompt = "Research topic",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(choice)
			if not choice then
				return
			end
			if choice.new then
				prompt_new(root)
				return
			end
			set_active(root, choice.title, choice.path)
		end))
	end
end)()

;(function --[[nav]]()
	-- active topic, or else the most recently touched research file.
	function nav.resolve_active_path()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			return nil, "research: could not determine a project root"
		end
		local path = active[root] and active[root].path
		if not path then
			local files = store.list_files(store.research_dir(root))
			table.sort(files, function(a, b)
				return (vim.fn.getftime(a) or 0) > (vim.fn.getftime(b) or 0)
			end)
			path = files[1]
		end
		if not path then
			return nil, "research: no research files yet for this repo, run :ResearchStart <name>"
		end
		return path
	end

	function nav.open()
		nav.list()
	end

	-- falls back to nav.open's picker if no active topic is set.
	function nav.open_active()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			vim.notify("research: could not determine a project root", vim.log.levels.ERROR)
			return
		end
		if active[root] and active[root].path then
			vim.cmd(research.config.split == "horizontal" and "new" or "vnew")
			vim.bo.bufhidden = "wipe"
			render.open(active[root].path)
			return
		end
		nav.open()
	end

	function nav.list()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			vim.notify("research: could not determine a project root", vim.log.levels.ERROR)
			return
		end
		local files = store.list_files(store.research_dir(root))
		if #files == 0 then
			vim.notify("research: no research files yet for this repo")
			return
		end
		local items = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(items, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end
		vim.ui.select(items, {
			prompt = "Research topic",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(choice)
			if not choice then
				return
			end
			active[root] = { topic = choice.title, path = choice.path }
			vim.cmd(research.config.split == "horizontal" and "new" or "vnew")
			vim.bo.bufhidden = "wipe"
			render.open(choice.path)
		end))
	end

	function nav.delete_topic()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			vim.notify("research: could not determine a project root", vim.log.levels.ERROR)
			return
		end
		local files = store.list_files(store.research_dir(root))
		if #files == 0 then
			vim.notify("research: no research files yet for this repo")
			return
		end
		local items = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(items, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end
		vim.ui.select(items, {
			prompt = "Delete which research topic?",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(choice)
			if not choice then
				return
			end
			if vim.fn.confirm("Delete topic '" .. choice.title .. "' and all its marks? This cannot be undone.", "&Yes\n&No", 2) ~= 1 then
				return
			end
			local view_buf = view_buffers[choice.path]
			if view_buf and vim.api.nvim_buf_is_valid(view_buf) then
				vim.api.nvim_buf_delete(view_buf, { force = true })
				view_buffers[choice.path] = nil
			end
			local storage_buf = vim.fn.bufnr(choice.path)
			if storage_buf ~= -1 then
				vim.api.nvim_buf_delete(storage_buf, { force = true })
			end
			if vim.fn.delete(choice.path) ~= 0 then
				vim.notify("research: failed to delete " .. choice.path, vim.log.levels.ERROR)
				return
			end
			if active[root] and active[root].path == choice.path then
				active[root] = nil
			end
			annotate.invalidate()
			annotate.sync_open_buffers()
			vim.notify("research: deleted topic '" .. choice.title .. "'")
		end))
	end

	-- like :ResearchMarkSync but file-wide and unattended (exact-search only).
	function nav.sync_all()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(filepath)
		if not root then
			vim.notify("research: could not determine a project root", vim.log.levels.ERROR)
			return
		end
		local files = store.list_files(store.research_dir(root))
		if #files == 0 then
			vim.notify("research: no research files yet for this repo")
			return
		end
		local items = {}
		for _, f in ipairs(files) do
			local fm = store.parse_frontmatter(f)
			table.insert(items, { path = f, title = (fm and fm.title) or vim.fn.fnamemodify(f, ":t") })
		end
		vim.ui.select(items, {
			prompt = "Sync all marks in which research topic?",
			format_item = function(item)
				return item.title
			end,
		}, guarded(function(choice)
			if not choice then
				return
			end
			local fm = store.parse_frontmatter(choice.path)
			if not fm or not fm.repo_path then
				vim.notify("research: could not determine repo_path for " .. choice.path, vim.log.levels.ERROR)
				return
			end
			local sync_root = vim.fn.expand(fm.repo_path)
			local _, blocks = store.parse_blocks(choice.path)
			local targets = {}
			for _, b in ipairs(blocks) do
				table.insert(targets, {
					file = b.file,
					line_start = b.line_start,
					line_end = b.line_end,
					commit = b.commit,
					name = (b.lines[1] or ""):gsub("^###%s*", ""),
				})
			end

			local synced = 0
			for _, mk in ipairs(targets) do
				local ok, msg = store.resync_mark(choice.path, sync_root, mk, "search", { require_unique = true })
				if ok then
					synced = synced + 1
				elseif msg ~= "already in sync" then
					vim.notify("research: sync failed for '" .. mk.name .. "': " .. msg, vim.log.levels.WARN)
				end
			end
			store.refresh_open_view(choice.path)
			vim.notify(string.format("research: synced %d/%d mark(s) in '%s'", synced, #targets, choice.title))
		end))
	end
end)()

;(function --[[stale]]()
	local ns = vim.api.nvim_create_namespace("research")

	local function buffer_frontmatter(bufnr)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 20, false)
		if lines[1] ~= "---" then
			return nil
		end
		local fm = {}
		for i = 2, #lines do
			if lines[i] == "---" then
				break
			end
			local k, v = lines[i]:match("^([%w_]+):%s*(.*)$")
			if k then
				fm[k] = v
			end
		end
		return fm
	end

	local function parse_marks(bufnr)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local marks = {}
		local heading_line = nil
		local in_fence = false
		local i = 1
		while i <= #lines do
			local l = lines[i]
			if l:match("^```") then
				in_fence = not in_fence
			elseif not in_fence and l:match("^### ") then
				heading_line = i
			elseif not in_fence and l:match("^<!%-%- research%-mark") then
				local block = { heading_line = heading_line, comment_line = i }
				local j = i + 1
				while j <= #lines and not lines[j]:match("^%-%->") do
					local k, v = lines[j]:match("^([%w_]+):%s*(.*)$")
					if k then
						block[k] = v
					end
					j = j + 1
				end
				block.comment_end_line = j
				marks[#marks + 1] = block
				i = j
			end
			i = i + 1
		end
		return marks
	end

	-- hash compare, not git-diff: diff can't tell pre-existing WIP from a real change.
	local function evaluate_mark(root, mk)
		if not mk.file or not mk.line_start or not mk.line_end then
			return "ok" -- malformed/hand-edited block; nothing sane to check
		end
		local abspath = root .. "/" .. mk.file
		if vim.fn.filereadable(abspath) == 0 then
			return "missing"
		end
		if not mk.hash or mk.hash == "" then
			return "ok" -- hand-edited or pre-hash mark; nothing to compare
		end
		local line_start = tonumber(mk.line_start)
		local line_end = tonumber(mk.line_end)
		if not line_start or not line_end then
			return "ok" -- hand-edited into non-numeric line numbers
		end
		local cur = store.safe_readfile(abspath, "", line_end)
		if not cur then
			return "ok" -- couldn't verify (transient read error); don't false-flag
		end
		local snippet = {}
		for i = line_start, math.min(line_end, #cur) do
			table.insert(snippet, cur[i])
		end
		if store.snippet_hash(snippet) ~= mk.hash then
			return "stale"
		end
		return "ok"
	end
	stale.evaluate_mark = evaluate_mark

	function stale.check(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		local marks = parse_marks(bufnr)

		local fm = buffer_frontmatter(bufnr)
		if not fm or not fm.repo_path then
			return
		end
		local root = vim.fn.expand(fm.repo_path)
		for _, mk in ipairs(marks) do
			local status = evaluate_mark(root, mk)
			local row = (mk.heading_line or mk.comment_line) - 1
			if status == "missing" then
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
					virt_text = { { research.config.icons.missing, "DiagnosticError" } },
					virt_text_pos = "right_align",
				})
			elseif status == "stale" then
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
					virt_text = { { research.config.icons.stale, "DiagnosticWarn" } },
					virt_text_pos = "right_align",
				})
			end
		end
	end

	local function mark_at_cursor(bufnr)
		local marks = parse_marks(bufnr)
		local cur = vim.fn.line(".")
		for idx, mk in ipairs(marks) do
			local region_start = mk.heading_line or mk.comment_line
			local next_mk = marks[idx + 1]
			local region_end = next_mk and ((next_mk.heading_line or next_mk.comment_line) - 1)
				or vim.api.nvim_buf_line_count(bufnr)
			if cur >= region_start and cur <= region_end then
				return mk
			end
		end
		return nil
	end

	local function resolve_target(bufnr)
		local fm = buffer_frontmatter(bufnr)
		if not fm or not fm.repo_path then
			return nil
		end
		local root = vim.fn.expand(fm.repo_path)
		local target = mark_at_cursor(bufnr)
		if not target then
			vim.notify("research: no mark under cursor")
			return nil
		end
		local abspath = root .. "/" .. target.file
		if vim.fn.filereadable(abspath) == 0 then
			vim.notify("research: source file missing: " .. target.file, vim.log.levels.ERROR)
			return nil
		end
		local line = tonumber(target.line_start)
		if not line then
			vim.notify("research: malformed line number in mark", vim.log.levels.ERROR)
			return nil
		end
		return abspath, line
	end

	function stale.jump(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		local abspath, line = resolve_target(bufnr)
		if not abspath then
			return
		end
		store.jump_to_source(abspath, line)
	end

	function stale.peek(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		local abspath, line = resolve_target(bufnr)
		if not abspath then
			return
		end
		store.jump_to_source(abspath, line, true)
	end

	function stale.yank(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		local target = mark_at_cursor(bufnr)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		vim.fn.setreg("+", target.file .. ":" .. (target.line_start or "?"))
	end
end)()

;(function --[[annotate]]()
	local ns = vim.api.nvim_create_namespace("research_annotate")

	-- [repo_root] = { [abspath] = { {research_path, topic, name, file,
	-- line_start, line_end, commit, hash, nstart, nend}, ... } } or nil.
	-- fields match render.build()'s identity fields; invalidated on write.
	local cache = nil

	function annotate.invalidate()
		cache = nil
	end

	local function build_repo_index(root)
		local index = {}
		for _, f in ipairs(store.list_files(store.research_dir(root))) do
			local fm = store.parse_frontmatter(f)
			local topic = (fm and fm.title) or vim.fn.fnamemodify(f, ":t:r")
			local _, blocks = store.parse_blocks(f)
			for _, b in ipairs(blocks) do
				local nstart, nend = tonumber(b.line_start), tonumber(b.line_end)
				-- skip hand-edited-into-garbage line numbers instead of crashing.
				if b.file and nstart and nend then
					local abspath = vim.fn.fnamemodify(root .. "/" .. b.file, ":p")
					local list = index[abspath]
					if not list then
						list = {}
						index[abspath] = list
					end
					table.insert(list, {
						research_path = f,
						topic = topic,
						name = b.lines[1] and b.lines[1]:match("^###%s*(.-)%s*|") or ("line " .. b.line_start),
						file = b.file,
						line_start = b.line_start,
						line_end = b.line_end,
						commit = b.commit,
						hash = b.hash,
						nstart = nstart,
						nend = nend,
					})
				end
			end
		end
		return index
	end

	-- ignores annotate_enabled: preview/goto work whether or not icons are on.
	function annotate.lookup(bufnr)
		if not store.is_project_file_buf(bufnr) then
			return nil
		end
		local abspath = vim.api.nvim_buf_get_name(bufnr)
		local root = store.repo_root(abspath)
		cache = cache or {}
		local index = cache[root]
		if not index then
			index = build_repo_index(root)
			cache[root] = index
		end
		return index[vim.fn.fnamemodify(abspath, ":p")], root
	end

	local function marks_for(bufnr)
		if not research.config.annotate_enabled then
			return nil
		end
		return annotate.lookup(bufnr)
	end

	-- called on BufReadPost and BufWritePost, so open and save always agree.
	function annotate.refresh(bufnr)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local marks, root = marks_for(bufnr)
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		if not marks then
			return
		end
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		for _, mk in ipairs(marks) do
			-- the file may have shrunk below the mark's recorded line since capture.
			if mk.nstart >= 1 and mk.nstart <= line_count then
				local status = stale.evaluate_mark(root, mk)
				local icon = research.config.icons.annotated
				if status == "stale" then
					icon = research.config.icons.stale
				elseif status == "missing" then
					icon = research.config.icons.missing
				end
				vim.api.nvim_buf_set_extmark(bufnr, ns, mk.nstart - 1, 0, {
					virt_text = { { icon, "DiagnosticHint" } },
					virt_text_pos = research.config.icon_virt_text_pos,
				})
			end
		end
	end

	-- so a mark mutation is reflected immediately, not on next read/write.
	function annotate.sync_open_buffers()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) and store.is_project_file_buf(buf) then
				annotate.refresh(buf)
				annotate.ensure_mark_keymaps(buf)
			end
		end
	end

	-- called from BufReadPost and sync_open_buffers, so a mark created
	-- mid-session gets its keymaps without needing a manual :e.
	function annotate.ensure_mark_keymaps(bufnr)
		if vim.b[bufnr].research_mark_keymaps then
			return
		end
		local marks = annotate.lookup(bufnr)
		if not marks or #marks == 0 then
			return
		end
		vim.b[bufnr].research_mark_keymaps = true
		local km = research.config.keymap
		safe_keymap("n", km.mark_preview, guarded(annotate.preview), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor",
		})
		safe_keymap("n", km.mark_preview_new, guarded(function()
			annotate.preview("float", true)
		end), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor (new floating window)",
		})
		safe_keymap("n", km.mark_preview_split, guarded(function()
			annotate.preview("split")
		end), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor (horizontal split)",
		})
		safe_keymap("n", km.mark_preview_split_new, guarded(function()
			annotate.preview("split", true)
		end), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor (new horizontal split)",
		})
		safe_keymap("n", km.mark_preview_vsplit, guarded(function()
			annotate.preview("vsplit")
		end), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor (vertical split)",
		})
		safe_keymap("n", km.mark_preview_vsplit_new, guarded(function()
			annotate.preview("vsplit", true)
		end), {
			buffer = bufnr,
			silent = true,
			desc = "research: preview mark under cursor (new vertical split)",
		})
		safe_keymap("n", km.mark_goto, guarded(annotate.goto_view), {
			buffer = bufnr,
			silent = true,
			desc = "research: go to mark in research view",
		})
		safe_keymap("n", km.help, guarded(show_keymap_help), {
			buffer = bufnr,
			silent = true,
			desc = "research: show keymaps",
		})
	end

	-- "search" mode, not git-offset: that diffs against a fixed commit, so
	-- uncommitted WIP compounds as false shift on every save. only relocates
	-- unambiguous matches; a real content edit just stays flagged stale.
	local QUIET_RESYNC_FAILURES = {
		["already in sync"] = true,
		["exact snippet not found in current file — still flagged stale"] = true,
	}
	function annotate.auto_resync(bufnr)
		if not research.config.annotate_auto_resync then
			return
		end
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local marks, root = annotate.lookup(bufnr)
		if not marks then
			return
		end
		local touched = {}
		for _, mk in ipairs(marks) do
			local ok, msg = store.resync_mark(mk.research_path, root, mk, "search", { require_unique = true })
			if ok then
				touched[mk.research_path] = true
				vim.notify("research: " .. msg)
			elseif not QUIET_RESYNC_FAILURES[msg] then
				vim.notify("research: auto-resync failed for '" .. mk.name .. "': " .. msg, vim.log.levels.WARN)
			end
		end
		for path in pairs(touched) do
			store.refresh_open_view(path)
		end
	end

	local function same_mark(m, mk)
		return m.file == mk.file
			and m.line_start == mk.line_start
			and m.line_end == mk.line_end
			and m.commit == mk.commit
	end

	-- mark(s) under the cursor's line: 0 notifies, 1 calls cb directly, 2+ shows a picker.
	local function resolve_mark(bufnr, cb)
		local marks = annotate.lookup(bufnr)
		if not marks then
			vim.notify("research: no mark on this line")
			return
		end
		local line = vim.fn.line(".")
		local cands = {}
		for _, mk in ipairs(marks) do
			if line >= mk.nstart and line <= mk.nend then
				table.insert(cands, mk)
			end
		end
		if #cands == 0 then
			vim.notify("research: no mark on this line")
		elseif #cands == 1 then
			cb(cands[1])
		else
			vim.ui.select(cands, {
				prompt = "Choose mark",
				format_item = function(mk)
					return mk.topic .. " — " .. mk.name
				end,
			}, guarded(function(choice)
				if choice then
					cb(choice)
				end
			end))
		end
	end

	-- unfocused preview of the mark under cursor, closes on move — like vim.lsp.buf.hover().
	local PREVIEW_MODES = { float = true, split = true, vsplit = true }
	-- [mode] = { win, buf } of the reusable window; "new" bypasses this.
	-- checks buf too, so a stale entry can't alias an unrelated reused winid.
	local preview_wins = {}
	-- one group per window, not shared: an independent "new" float must never
	-- clear, or be cleared by, another float's pending auto-close.
	local function float_close_group(win)
		return vim.api.nvim_create_augroup("research_preview_float_close_" .. win, { clear = false })
	end

	-- srcbuf (float only): its own <Esc> to close from wherever the cursor
	-- is, removed here too so it's never left dangling.
	local function close_preview(mode, win, srcbuf)
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if preview_wins[mode] and preview_wins[mode].win == win then
			preview_wins[mode] = nil
		end
		if srcbuf and vim.api.nvim_buf_is_valid(srcbuf) then
			pcall(vim.keymap.del, "n", "<Esc>", { buffer = srcbuf })
		end
	end

	-- clamped to [min_ratio,max_ratio] of total either way.
	local function resolve_size(setting, content_size, total, min_ratio, max_ratio)
		local size
		if setting == "content" or setting == true then
			size = content_size
		elseif type(setting) == "number" then
			size = math.floor(total * setting)
		else
			size = math.floor(total * max_ratio)
		end
		local lo = math.max(1, math.floor(total * min_ratio))
		local hi = math.max(lo, math.floor(total * max_ratio))
		return math.max(lo, math.min(size, hi))
	end

	-- follow: allowed to move focus into a reused preview? annotate.jump
	-- passes false so paging next/prev never yanks you off the source.
	function annotate.preview(mode, new, follow)
		if follow == nil then
			follow = true
		end
		mode = mode or "float"
		if not PREVIEW_MODES[mode] then
			vim.notify("research: preview mode must be float, split, or vsplit", vim.log.levels.ERROR)
			return
		end
		local bufnr = vim.api.nvim_get_current_buf()
		local origin_win = vim.api.nvim_get_current_win()
		resolve_mark(bufnr, guarded(function(mk)
			local view_lines, marks = render.build_marks(mk.research_path)
			local idx = nil
			for i, m in ipairs(marks) do
				if same_mark(m, mk) then
					idx = i
					break
				end
			end
			if not idx then
				vim.notify("research: mark not found in storage", vim.log.levels.ERROR)
				return
			end
			local start_row = marks[idx].heading_line or marks[idx].path_line
			local end_row = marks[idx + 1] and ((marks[idx + 1].heading_line or marks[idx + 1].path_line) - 1)
				or #view_lines
			local slice = {}
			for i = start_row, end_row do
				table.insert(slice, view_lines[i])
			end
			-- drop the trailing "---" separator — file layout, not mark content.
			while #slice > 0 and vim.trim(slice[#slice]) == "" do
				table.remove(slice)
			end
			if #slice > 0 and vim.trim(slice[#slice]) == "---" then
				table.remove(slice)
				while #slice > 0 and vim.trim(slice[#slice]) == "" do
					table.remove(slice)
				end
			end

			local tracked = not new and preview_wins[mode]
			local reuse = tracked
				and vim.api.nvim_win_is_valid(tracked.win)
				and vim.api.nvim_win_get_buf(tracked.win) == tracked.buf
			local existing = reuse and tracked.win

			local fbuf
			if reuse then
				fbuf = tracked.buf
				vim.bo[fbuf].modifiable = true
				vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, slice)
				vim.bo[fbuf].modifiable = false
			else
				fbuf = vim.api.nvim_create_buf(false, true)
				vim.bo[fbuf].filetype = "markdown"
				vim.bo[fbuf].bufhidden = "wipe"
				vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, slice)
				vim.bo[fbuf].modifiable = false
			end

			local content_width = 0
			for _, l in ipairs(slice) do
				content_width = math.max(content_width, #l)
			end
			content_width = content_width + 2
			local content_height = math.max(#slice, 1)

			if mode == "split" or mode == "vsplit" then
				local win
				if reuse then
					win = existing
				else
					vim.cmd(mode)
					win = vim.api.nvim_get_current_win()
					vim.api.nvim_win_set_buf(win, fbuf)
					if not new then
						preview_wins[mode] = { win = win, buf = fbuf }
					end
					-- float gets this free via style="minimal"; a split needs it
					-- explicit or number/sign/fold columns eat the content width.
					vim.wo[win].number = false
					vim.wo[win].relativenumber = false
					vim.wo[win].signcolumn = "no"
					vim.wo[win].foldcolumn = "0"
					vim.wo[win].wrap = true
				end

				local cfg = research.config.preview[mode]
				if mode == "split" then
					vim.api.nvim_win_set_height(
						win,
						resolve_size(cfg.height, content_height, vim.o.lines, cfg.min, cfg.max)
					)
				else
					vim.api.nvim_win_set_width(
						win,
						resolve_size(cfg.width, content_width, vim.o.columns, cfg.min, cfg.max)
					)
				end

				vim.keymap.set("n", "q", guarded(function()
					close_preview(mode, win)
				end), { buffer = fbuf, silent = true })
				vim.keymap.set("n", "<Esc>", guarded(function()
					close_preview(mode, win)
				end), { buffer = fbuf, silent = true })

				-- reusing an open preview counts as "take me there" regardless
				-- of preview_jump, unless follow is false (jump paging).
				if follow and (reuse or research.config.preview_jump) then
					vim.api.nvim_set_current_win(win)
				elseif vim.api.nvim_win_is_valid(origin_win) then
					vim.api.nvim_set_current_win(origin_win)
				end
				return
			end

			local fcfg = research.config.preview.float
			local float_opts = {
				relative = "cursor",
				row = 1,
				col = 0,
				width = resolve_size(fcfg.width, content_width, vim.o.columns, fcfg.min, fcfg.max),
				height = resolve_size(fcfg.height, content_height, vim.o.lines, fcfg.min, fcfg.max),
				style = "minimal",
				border = "rounded",
			}

			local win
			if reuse then
				win = existing
				vim.api.nvim_win_set_config(win, float_opts)
			else
				win = vim.api.nvim_open_win(fbuf, false, float_opts)
				vim.wo[win].wrap = true
				if not new then
					preview_wins.float = { win = win, buf = fbuf }
				end
			end
			-- must clear synchronously, before anything else: the caller's own
			-- cursor move (e.g. annotate.jump landing here) fires a stale
			-- CursorMoved as soon as this returns; a deferred clear (vim.schedule)
			-- would let a reused window's old watcher catch it and close this.
			vim.api.nvim_clear_autocmds({ group = float_close_group(win) })
			local jumped = follow and (reuse or research.config.preview_jump)
			if jumped then
				vim.api.nvim_set_current_win(win)
			end

			vim.keymap.set("n", "q", guarded(function()
				close_preview("float", win, bufnr)
			end), { buffer = fbuf, silent = true })
			vim.keymap.set("n", "<Esc>", guarded(function()
				close_preview("float", win, bufnr)
			end), { buffer = fbuf, silent = true })

			-- <Esc> also needs to work from the source buffer, unfocused float or not.
			vim.keymap.set("n", "<Esc>", guarded(function()
				close_preview("float", win, bufnr)
			end), { buffer = bufnr, silent = true })

			-- only an un-jumped float auto-closes (transient hover); split/vsplit
			-- or jumped-into is a deliberate window you close yourself.
			-- deferred: the caller's own cursor move (e.g. annotate.jump landing
			-- here) is still in flight — registering now would self-close on arrival.
			if not jumped then
				vim.schedule(guarded(function()
					if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(bufnr) then
						return
					end
					local group = float_close_group(win)
					vim.api.nvim_clear_autocmds({ group = group })
					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }, {
						group = group,
						buffer = bufnr,
						once = true,
						callback = guarded(function()
							-- only tear down if the window is still ours (not repurposed since).
							if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == fbuf then
								close_preview("float", win, bufnr)
							end
						end),
					})
				end))
			end
		end))
	end

	function annotate.goto_view()
		local bufnr = vim.api.nvim_get_current_buf()
		resolve_mark(bufnr, guarded(function(mk)
			local viewbuf = view_buffers[mk.research_path]
			local win = nil
			if viewbuf and vim.api.nvim_buf_is_valid(viewbuf) then
				for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if vim.api.nvim_win_get_buf(w) == viewbuf then
						win = w
						break
					end
				end
			end
			if win then
				vim.api.nvim_set_current_win(win)
				render.open(mk.research_path, win)
			else
				vim.cmd(research.config.split == "horizontal" and "new" or "vnew")
				vim.bo.bufhidden = "wipe"
				render.open(mk.research_path)
				win = vim.api.nvim_get_current_win()
			end

			local st = view_state[vim.api.nvim_win_get_buf(win)]
			local idx = nil
			if st then
				for i, m in ipairs(st.marks) do
					if same_mark(m, mk) then
						idx = i
						break
					end
				end
			end
			if idx then
				local row = st.marks[idx].heading_line or st.marks[idx].path_line
				vim.api.nvim_win_set_cursor(win, { row, 0 })
			end
		end))
	end

	-- moves the cursor to the next/prev mark (by line_start) in the current
	-- buffer, wrapping around; a no-op if it has no marks at all (a single
	-- mark still "wraps" to itself, e.g. jumping to it from elsewhere).
	function annotate.jump(direction, preview)
		local bufnr = vim.api.nvim_get_current_buf()
		local marks = annotate.lookup(bufnr)
		if not marks or #marks < 1 then
			return
		end
		local sorted = vim.deepcopy(marks)
		table.sort(sorted, function(a, b)
			return a.nstart < b.nstart
		end)

		local cur = vim.fn.line(".")
		local target
		if direction == "next" then
			for _, mk in ipairs(sorted) do
				if mk.nstart > cur then
					target = mk
					break
				end
			end
			target = target or sorted[1]
		elseif direction == "prev" then
			for i = #sorted, 1, -1 do
				if sorted[i].nstart < cur then
					target = sorted[i]
					break
				end
			end
			target = target or sorted[#sorted]
		else
			vim.notify("research: jump direction must be 'next' or 'prev'", vim.log.levels.ERROR)
			return
		end

		vim.api.nvim_win_set_cursor(0, { target.nstart, 0 })
		if preview then
			annotate.preview(nil, nil, false) -- follow=false: never pulled into the float while paging
		end
	end
end)()

;(function --[[render]]()
	local function build(path)
		local lines = store.safe_readfile(path) or {}
		local view_lines = {}
		local marks = {}
		local heading_line = nil
		local i = 1

		if lines[1] == "---" then
			i = 2
			while i <= #lines and lines[i] ~= "---" do
				i = i + 1
			end
			i = i + 1
			while i <= #lines and vim.trim(lines[i]) == "" do
				i = i + 1
			end
		end

		local in_fence = false
		while i <= #lines do
			local l = lines[i]
			if l:match("^```") then
				in_fence = not in_fence
				table.insert(view_lines, l)
				i = i + 1
			elseif not in_fence and l:match("^### ") then
				table.insert(view_lines, l)
				heading_line = #view_lines
				i = i + 1
			elseif not in_fence and l:match("^<!%-%- research%-mark") then
				local fields = {}
				local j = i + 1
				while j <= #lines and not lines[j]:match("^%-%->") do
					local k, v = lines[j]:match("^([%w_]+):%s*(.*)$")
					if k then
						fields[k] = v
					end
					j = j + 1
				end
				table.insert(view_lines, (fields.file or "?") .. ":" .. (fields.line_start or "?"))
				table.insert(marks, {
					heading_line = heading_line,
					path_line = #view_lines,
					file = fields.file,
					line_start = fields.line_start,
					line_end = fields.line_end,
					commit = fields.commit,
					hash = fields.hash,
					selection = fields.selection,
				})
				i = j + 1
				-- context-only marks hide the snippet by default (km.snippet pops it up).
				if fields.selection == "false" and lines[i] and lines[i]:match("^```") then
					i = i + 1
					while i <= #lines and not lines[i]:match("^```") do
						i = i + 1
					end
					i = i + 1
				end
			else
				table.insert(view_lines, l)
				i = i + 1
			end
		end
		return view_lines, marks
	end
	render.build_marks = build

	function render.open(path, win)
		store.ensure_win_tracking()
		win = win or vim.api.nvim_get_current_win()
		local view_lines, marks = build(path)

		local buf = view_buffers[path]
		if not buf or not vim.api.nvim_buf_is_valid(buf) then
			buf = vim.api.nvim_create_buf(false, true)
			view_buffers[path] = buf
			vim.bo[buf].buftype = "nofile"
			vim.bo[buf].swapfile = false
			vim.bo[buf].bufhidden = "hide"
			-- slash-free: a path-like name risks being misread as real and written to disk.
			vim.api.nvim_buf_set_name(buf, "research-view:" .. vim.fn.sha256(path):sub(1, 16))
			block_reload(buf)
		end

		-- re-set every open (not just on creation) so FileType re-fires — some
		-- highlighters detach on hide and only reattach on that event.
		vim.bo[buf].filetype = "markdown"

		-- re-applied every open so keymap config changes reach a cached view buffer.
		local km = research.config.keymap
		safe_keymap("n", km.jump, guarded(function()
			render.jump(buf)
		end), { buffer = buf, silent = true, desc = "research: jump to source" })
		safe_keymap("n", km.peek, guarded(function()
			render.peek(buf)
		end), { buffer = buf, silent = true, desc = "research: peek source (keep focus here)" })
		safe_keymap("n", km.toggle, guarded(function()
			render.edit_mark(buf)
		end), { buffer = buf, silent = true, desc = "research: edit the mark under cursor (title/note/snippet)" })
		safe_keymap("n", km.delete, guarded(function()
			render.delete(buf)
		end), { buffer = buf, silent = true, desc = "research: delete mark under cursor" })
		safe_keymap("n", km.move_down, guarded(function()
			render.move(buf, 1)
		end), { buffer = buf, silent = true, desc = "research: move mark down" })
		safe_keymap("n", km.move_up, guarded(function()
			render.move(buf, -1)
		end), { buffer = buf, silent = true, desc = "research: move mark up" })
		safe_keymap("n", km.sync, guarded(function()
			render.sync(buf)
		end), { buffer = buf, silent = true, desc = "research: resync mark under cursor" })
		safe_keymap("n", km.snippet, guarded(function()
			render.show_snippet(buf)
		end), { buffer = buf, silent = true, desc = "research: pop up mark's stored snippet" })
		safe_keymap("n", km.toggle_snippet, guarded(function()
			render.toggle_snippet(buf)
		end), { buffer = buf, silent = true, desc = "research: show/hide mark's snippet inline" })
		safe_keymap("n", km.yank, guarded(function()
			render.yank(buf)
		end), { buffer = buf, silent = true, desc = "research: copy mark's file:line to clipboard" })
		safe_keymap("n", km.help, guarded(show_keymap_help), {
			buffer = buf,
			silent = true,
			desc = "research: show keymaps",
		})

		vim.bo[buf].modifiable = true
		vim.bo[buf].readonly = false
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, view_lines)
		vim.bo[buf].modifiable = false
		vim.bo[buf].readonly = true
		vim.bo[buf].modified = false

		view_state[buf] = { path = path, marks = marks }
		vim.api.nvim_win_set_buf(win, buf)

		local ns = vim.api.nvim_create_namespace("research")
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		local fm = store.parse_frontmatter(path)
		local root = fm and fm.repo_path and vim.fn.expand(fm.repo_path)
		if not root then
			return
		end
		for _, mk in ipairs(marks) do
			local status = stale.evaluate_mark(root, mk)
			local row = (mk.heading_line or mk.path_line) - 1
			if status == "missing" then
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					virt_text = { { research.config.icons.missing, "DiagnosticError" } },
					virt_text_pos = "right_align",
				})
			elseif status == "stale" then
				vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
					virt_text = { { research.config.icons.stale, "DiagnosticWarn" } },
					virt_text_pos = "right_align",
				})
			end
		end
	end

	-- the mark whose region (heading to just before the next) contains the cursor, or nil.
	local function mark_at_cursor(buf)
		local st = view_state[buf]
		if not st then
			return nil
		end
		local cur = vim.fn.line(".")
		for idx, mk in ipairs(st.marks) do
			local region_start = mk.heading_line or mk.path_line
			local next_mk = st.marks[idx + 1]
			local region_end = next_mk and ((next_mk.heading_line or next_mk.path_line) - 1)
				or vim.api.nvim_buf_line_count(buf)
			if cur >= region_start and cur <= region_end then
				return mk
			end
		end
		return nil
	end

	-- finds the block matching a view mark by its file/line/commit identity.
	local function find_block_index(blocks, mk)
		for i, b in ipairs(blocks) do
			if
				b.file == mk.file
				and b.line_start == mk.line_start
				and b.line_end == mk.line_end
				and b.commit == mk.commit
			then
				return i
			end
		end
		return nil
	end

	local function resolve_target(buf)
		local st = view_state[buf]
		if not st then
			return nil
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return nil
		end
		local fm = store.parse_frontmatter(st.path)
		if not fm or not fm.repo_path then
			return nil
		end
		local root = vim.fn.expand(fm.repo_path)
		local abspath = root .. "/" .. target.file
		if vim.fn.filereadable(abspath) == 0 then
			vim.notify("research: source file missing: " .. target.file, vim.log.levels.ERROR)
			return nil
		end
		local line = tonumber(target.line_start)
		if not line then
			vim.notify("research: malformed line number in mark", vim.log.levels.ERROR)
			return nil
		end
		return abspath, line
	end

	function render.jump(buf)
		local abspath, line = resolve_target(buf)
		if not abspath then
			return
		end
		store.jump_to_source(abspath, line)
	end

	function render.peek(buf)
		local abspath, line = resolve_target(buf)
		if not abspath then
			return
		end
		store.jump_to_source(abspath, line, true)
	end

	function render.yank(buf)
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		vim.fn.setreg("+", target.file .. ":" .. (target.line_start or "?"))
	end

	function render.show_snippet(buf)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local _, blocks = store.parse_blocks(st.path)
		local idx = find_block_index(blocks, target)
		if not idx then
			vim.notify("research: could not locate mark in storage", vim.log.levels.ERROR)
			return
		end
		local snippet = store.extract_snippet(blocks[idx].lines)
		if #snippet == 0 then
			vim.notify("research: this mark has no stored snippet")
			return
		end

		local popup_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[popup_buf].buftype = "nofile"
		vim.bo[popup_buf].bufhidden = "wipe"
		vim.bo[popup_buf].swapfile = false
		vim.bo[popup_buf].filetype = vim.filetype.match({ filename = target.file or "" }) or ""
		vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, snippet)
		vim.bo[popup_buf].modifiable = false

		local width = 40
		for _, l in ipairs(snippet) do
			width = math.max(width, #l)
		end
		width = math.min(width + 2, vim.o.columns - 4)
		local height = math.min(#snippet, 20)

		local win = vim.api.nvim_open_win(popup_buf, true, {
			relative = "cursor",
			row = 1,
			col = 0,
			width = width,
			height = height,
			style = "minimal",
			border = "rounded",
			title = " " .. (target.file or "snippet") .. " (q to close) ",
			title_pos = "center",
		})
		local function close()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end
		vim.keymap.set("n", "q", guarded(close), { buffer = popup_buf, silent = true })
		vim.keymap.set("n", "<Esc>", guarded(close), { buffer = popup_buf, silent = true })
	end

	function render.delete(buf)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local header, blocks = store.parse_blocks(st.path)
		local idx = find_block_index(blocks, target)
		if not idx then
			vim.notify("research: could not locate mark in storage", vim.log.levels.ERROR)
			return
		end
		local label = blocks[idx].lines[1] or target.file
		if vim.fn.confirm("Delete mark: " .. label .. "?", "&Yes\n&No", 2) ~= 1 then
			return
		end
		table.remove(blocks, idx)
		if not store.write_blocks(st.path, header, blocks) then
			return
		end
		render.open(st.path)
		vim.notify("research: mark deleted")
	end

	-- direction: -1 swaps up, 1 swaps down.
	function render.move(buf, direction)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local header, blocks = store.parse_blocks(st.path)
		local idx = find_block_index(blocks, target)
		if not idx then
			vim.notify("research: could not locate mark in storage", vim.log.levels.ERROR)
			return
		end
		local swap_idx = idx + direction
		if swap_idx < 1 or swap_idx > #blocks then
			vim.notify("research: mark is already at the " .. (direction < 0 and "top" or "bottom"))
			return
		end
		blocks[idx], blocks[swap_idx] = blocks[swap_idx], blocks[idx]
		if not store.write_blocks(st.path, header, blocks) then
			return
		end
		render.open(st.path)

		for _, mk in ipairs(view_state[buf].marks) do
			if
				mk.file == target.file
				and mk.line_start == target.line_start
				and mk.line_end == target.line_end
				and mk.commit == target.commit
			then
				vim.api.nvim_win_set_cursor(0, { mk.heading_line or mk.path_line, 0 })
				break
			end
		end
	end

	-- flips selection, which the view reads to show/hide the snippet inline.
	function render.toggle_snippet(buf)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local header, blocks = store.parse_blocks(st.path)
		local idx = find_block_index(blocks, target)
		if not idx then
			vim.notify("research: could not locate mark in storage", vim.log.levels.ERROR)
			return
		end
		local was_hidden = target.selection == "false"
		store.set_field(blocks[idx].lines, "selection", tostring(was_hidden))
		if not store.write_blocks(st.path, header, blocks) then
			return
		end
		render.open(st.path)

		for _, mk in ipairs(view_state[buf].marks) do
			if
				mk.file == target.file
				and mk.line_start == target.line_start
				and mk.line_end == target.line_end
				and mk.commit == target.commit
			then
				vim.api.nvim_win_set_cursor(0, { mk.heading_line or mk.path_line, 0 })
				break
			end
		end
	end

	function render.sync(buf)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local fm = store.parse_frontmatter(st.path)
		if not fm or not fm.repo_path then
			return
		end
		local root = vim.fn.expand(fm.repo_path)

		local function run(mode)
			local ok, msg = store.resync_mark(st.path, root, target, mode)
			if ok then
				vim.notify("research: " .. msg)
			elseif msg ~= "already in sync" then
				vim.notify("research: " .. msg, vim.log.levels.WARN)
			end
			render.open(st.path)
		end

		-- no commit means git-offset can't work — skip straight to search.
		if not target.commit or target.commit == "" then
			run("search")
			return
		end

		vim.ui.select({
			"Sync via git (offset shift only)",
			"Exact search for original snippet",
		}, {
			prompt = "Resync mark " .. (target.file or "?") .. ":" .. (target.line_start or "?"),
		}, guarded(function(choice)
			if not choice then
				return
			end
			run(choice:match("^Sync via git") and "git" or "search")
		end))
	end

	-- same transform as build(), scoped to one block; unlike the readonly
	-- view this always shows the snippet, even for a context-only mark.
	local function block_to_view_lines(lines)
		local out = {}
		local i = 1
		local in_fence = false
		while i <= #lines do
			local l = lines[i]
			if l:match("^```") then
				in_fence = not in_fence
				table.insert(out, l)
				i = i + 1
			elseif not in_fence and l:match("^<!%-%- research%-mark") then
				local fields = {}
				local j = i + 1
				while j <= #lines and not lines[j]:match("^%-%->") do
					local k, v = lines[j]:match("^([%w_]+):%s*(.*)$")
					if k then
						fields[k] = v
					end
					j = j + 1
				end
				table.insert(out, (fields.file or "?") .. ":" .. (fields.line_start or "?"))
				i = j + 1
			else
				table.insert(out, l)
				i = i + 1
			end
		end
		return out
	end

	-- the language tag off the block's existing fence, e.g. "lua" from "```lua".
	local function fence_lang(lines)
		for _, l in ipairs(lines) do
			local lang = l:match("^```(.*)$")
			if lang then
				return lang
			end
		end
		return ""
	end

	-- closing fence index; the note (if any) always trails right after it.
	local function fence_end_index(lines)
		local comment_idx, close_idx, fence_start
		for i, l in ipairs(lines) do
			if l:match("^<!%-%- research%-mark") then
				comment_idx = i
				break
			end
		end
		if not comment_idx then
			return nil
		end
		for i = comment_idx + 1, #lines do
			if lines[i]:match("^%-%->") then
				close_idx = i
				break
			end
		end
		if not close_idx then
			return nil
		end
		for i = close_idx + 1, #lines do
			if lines[i]:match("^```") then
				fence_start = i
				break
			end
		end
		if not fence_start then
			return close_idx
		end
		for i = fence_start + 1, #lines do
			if lines[i]:match("^```") then
				return i
			end
		end
		return fence_start
	end

	-- swaps a block's heading and its trailing note (the free-form text after
	-- the closing fence), leaving the comment/fence themselves untouched —
	-- call after store.replace_block_snippet, if that's also needed, so this
	-- locates the (possibly resized) fence's actual end.
	local function replace_heading_and_note(block, new_heading, new_note)
		local fence_end = fence_end_index(block.lines)
		if not fence_end then
			return false
		end
		while #block.lines > fence_end do
			table.remove(block.lines)
		end
		-- verbatim: whatever spacing you left is exactly what gets written back.
		vim.list_extend(block.lines, new_note)
		block.lines[1] = new_heading
		return true
	end

	-- editable title/note/snippet; file/line/commit/hash stay hidden and untouched.
	function render.edit_mark(buf)
		local st = view_state[buf]
		if not st then
			return
		end
		local target = mark_at_cursor(buf)
		if not target then
			vim.notify("research: no mark under cursor")
			return
		end
		local _, blocks = store.parse_blocks(st.path)
		local idx = find_block_index(blocks, target)
		if not idx then
			vim.notify("research: could not locate mark in storage", vim.log.levels.ERROR)
			return
		end
		local block = blocks[idx]
		local ft = fence_lang(block.lines)
		local anchor = (target.file or "?") .. ":" .. (target.line_start or "?")

		local editbuf = vim.api.nvim_create_buf(false, true)
		vim.bo[editbuf].buftype = "acwrite"
		vim.bo[editbuf].swapfile = false
		vim.bo[editbuf].bufhidden = "wipe"
		vim.bo[editbuf].filetype = "markdown"
		vim.api.nvim_buf_set_name(editbuf, "research-edit:" .. vim.fn.sha256(st.path .. anchor):sub(1, 16))
		block_reload(editbuf)
		vim.api.nvim_buf_set_lines(editbuf, 0, -1, false, block_to_view_lines(block.lines))
		vim.bo[editbuf].modified = false
		local km = research.config.keymap
		safe_keymap("n", km.help, guarded(show_keymap_help), {
			buffer = editbuf,
			silent = true,
			desc = "research: show keymaps",
		})
		vim.keymap.set("n", "q", guarded(function()
			if vim.bo[editbuf].modified then
				if vim.fn.confirm("Discard unsaved changes to this mark?", "&Yes\n&No", 2) ~= 1 then
					return
				end
			end
			-- explicitly discard: an editbuf left modified would refuse to
			-- get wiped (bufhidden=wipe) and could block a later :e elsewhere.
			vim.bo[editbuf].modified = false
			render.open(st.path)
		end), { buffer = editbuf, silent = true, desc = "research: cancel edit, back to view" })

		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = editbuf,
			callback = guarded(function()
				local lines = vim.api.nvim_buf_get_lines(editbuf, 0, -1, false)
				local new_heading = lines[1]
				if not new_heading or not new_heading:match("^### ") then
					vim.notify("research: first line must stay a '### title' heading", vim.log.levels.ERROR)
					return
				end

				local anchor_idx = nil
				for i = 2, #lines do
					if lines[i] == anchor then
						anchor_idx = i
						break
					end
				end
				if not anchor_idx then
					vim.notify("research: don't edit or remove the '" .. anchor .. "' line", vim.log.levels.ERROR)
					return
				end

				-- note trails the fence — see save_mark's entry layout.
				local fstart = anchor_idx + 1
				while fstart <= #lines and vim.trim(lines[fstart]) == "" do
					fstart = fstart + 1
				end
				if not lines[fstart] or not lines[fstart]:match("^```") then
					vim.notify("research: snippet fence is missing or malformed", vim.log.levels.ERROR)
					return
				end
				local fend = fstart + 1
				while fend <= #lines and not lines[fend]:match("^```") do
					fend = fend + 1
				end
				if fend > #lines then
					vim.notify("research: snippet fence is missing its closing ```", vim.log.levels.ERROR)
					return
				end
				local new_snippet = {}
				for i = fstart + 1, fend - 1 do
					table.insert(new_snippet, lines[i])
				end
				-- verbatim; only the trailing end gets trimmed (parse_blocks does the same).
				local new_note = {}
				for i = fend + 1, #lines do
					table.insert(new_note, lines[i])
				end
				while #new_note > 0 and vim.trim(new_note[#new_note]) == "" do
					table.remove(new_note)
				end

				local header, cur_blocks = store.parse_blocks(st.path)
				local cur_idx = find_block_index(cur_blocks, target)
				if not cur_idx then
					vim.notify("research: mark no longer exists in storage", vim.log.levels.ERROR)
					return
				end
				local cur_block = cur_blocks[cur_idx]
				-- must track the edited snippet's length or the hash compares
				-- against the wrong number of file lines and always shows stale.
				local new_line_end = (tonumber(target.line_start) or 1) + math.max(#new_snippet, 1) - 1
				store.replace_block_snippet(cur_block, {
					file = target.file,
					line_start = target.line_start,
					line_end = tostring(new_line_end),
					commit = target.commit,
					hash = store.snippet_hash(new_snippet),
					selection = target.selection,
				}, ft, new_snippet)
				replace_heading_and_note(cur_block, new_heading, new_note)
				if not store.write_blocks(st.path, header, cur_blocks) then
					return
				end
				vim.bo[editbuf].modified = false
				vim.notify("research: mark updated")
				render.open(st.path)
			end),
		})

		vim.api.nvim_win_set_buf(0, editbuf)
	end

	function render.edit(path)
		if not path then
			local bufnr = vim.api.nvim_get_current_buf()
			local st = view_state[bufnr]
			if st then
				path = st.path
			else
				local err
				path, err = nav.resolve_active_path()
				if not path then
					vim.notify(err, vim.log.levels.ERROR)
					return
				end
				vim.cmd(research.config.split == "horizontal" and "new" or "vnew")
				vim.bo.bufhidden = "wipe"
			end
		end
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end
end)()

;(function --[[commands]]()
	vim.api.nvim_create_user_command("ResearchStart", guarded(function(opts)
		capture.start(opts.args)
	end), { nargs = "?", desc = "Set the active research topic for this repo (prompts/picks if no name given)" })

	vim.api.nvim_create_user_command("ResearchMark", guarded(function(opts)
		capture.mark(opts.range > 0, opts.line1, opts.line2)
	end), { range = true, desc = "Capture a research mark, choosing which research topic to add it to" })

	vim.api.nvim_create_user_command("ResearchMarkInActiveResearch", guarded(function(opts)
		capture.mark_active(opts.range > 0, opts.line1, opts.line2)
	end), {
		range = true,
		desc = "Capture a mark straight into the active topic, or fall back to :ResearchMark",
	})

	vim.api.nvim_create_user_command("ResearchMarkResnippet", guarded(function(opts)
		capture.resnippet(opts.range > 0, opts.line1, opts.line2)
	end), {
		range = true,
		desc = "Re-point an existing mark's snippet/location at the current cursor or selection",
	})

	vim.api.nvim_create_user_command("ResearchOpen", guarded(function()
		nav.open()
	end), { desc = "Pick a research topic to open for this repo" })

	vim.api.nvim_create_user_command("ResearchOpenActive", guarded(function()
		nav.open_active()
	end), { desc = "Open the active research topic directly, or fall back to :ResearchOpen" })

	vim.api.nvim_create_user_command("ResearchList", guarded(function()
		nav.list()
	end), { desc = "Pick a research topic for this repo" })

	vim.api.nvim_create_user_command("ResearchDelete", guarded(function()
		nav.delete_topic()
	end), { desc = "Delete a whole research topic (all its marks), with confirmation" })

	vim.api.nvim_create_user_command("ResearchSync", guarded(function()
		nav.sync_all()
	end), { desc = "Resync every mark in a chosen research topic (exact-search, unattended)" })

	vim.api.nvim_create_user_command("ResearchCheck", guarded(function()
		stale.check(0)
	end), { desc = "Re-check staleness of marks in this research buffer" })

	vim.api.nvim_create_user_command("ResearchEdit", guarded(function()
		render.edit()
	end), { desc = "Edit the active research file directly (storage mode)" })

	vim.api.nvim_create_user_command("ResearchMarkDelete", guarded(function()
		render.delete(vim.api.nvim_get_current_buf())
	end), { desc = "Delete the mark under cursor in this research view (with confirmation)" })

	vim.api.nvim_create_user_command("ResearchMarkMoveUp", guarded(function()
		render.move(vim.api.nvim_get_current_buf(), -1)
	end), { desc = "Move the mark under cursor up (swap with the previous one)" })

	vim.api.nvim_create_user_command("ResearchMarkMoveDown", guarded(function()
		render.move(vim.api.nvim_get_current_buf(), 1)
	end), { desc = "Move the mark under cursor down (swap with the next one)" })

	vim.api.nvim_create_user_command("ResearchMarkSync", guarded(function()
		render.sync(vim.api.nvim_get_current_buf())
	end), { desc = "Resync the mark under cursor: git offset shift or exact snippet search" })

	vim.api.nvim_create_user_command("ResearchMarkSnippet", guarded(function()
		render.show_snippet(vim.api.nvim_get_current_buf())
	end), { desc = "Pop up the stored snippet for the mark under cursor" })

	local function peek(bufnr)
		-- normalize the 0/nil sentinel: view_state is a plain table, indexed ourselves.
		if not bufnr or bufnr == 0 then
			bufnr = vim.api.nvim_get_current_buf()
		end
		if view_state[bufnr] then
			render.peek(bufnr)
		else
			stale.peek(bufnr)
		end
	end

	vim.api.nvim_create_user_command("ResearchPeek", guarded(function()
		peek()
	end), { desc = "Show the mark under cursor's source without leaving this buffer" })

	vim.api.nvim_create_user_command("ResearchMarkPreview", guarded(function(opts)
		annotate.preview(opts.fargs[1], opts.fargs[2] == "new")
	end), {
		nargs = "*",
		complete = function(arg_lead, cmdline)
			local words = vim.split(vim.trim(cmdline), "%s+")
			local arg_count = #words - 1 + (cmdline:match("%s$") and 1 or 0)
			local candidates = arg_count <= 1 and { "float", "split", "vsplit" } or { "new" }
			if arg_lead == "" then
				return candidates
			end
			return vim.tbl_filter(function(c)
				return c:sub(1, #arg_lead) == arg_lead
			end, candidates)
		end,
		desc = "Preview the mark under cursor: float (default)/split/vsplit, reusing that mode's "
			.. "window unless 'new' is given",
	})

	vim.api.nvim_create_user_command("ResearchMarkGoto", guarded(function()
		annotate.goto_view()
	end), { desc = "Jump to the mark under cursor (project file buffers) in its research view" })

	vim.api.nvim_create_user_command("ResearchJump", guarded(function(opts)
		local direction = opts.fargs[1]
		if direction ~= "next" and direction ~= "prev" then
			vim.notify("research: usage :ResearchJump next|prev [preview]", vim.log.levels.ERROR)
			return
		end
		annotate.jump(direction, opts.fargs[2] == "preview")
	end), {
		nargs = "*",
		complete = function(arg_lead, cmdline)
			local words = vim.split(vim.trim(cmdline), "%s+")
			local arg_count = #words - 1 + (cmdline:match("%s$") and 1 or 0)
			local candidates = arg_count <= 1 and { "next", "prev" } or { "preview" }
			if arg_lead == "" then
				return candidates
			end
			return vim.tbl_filter(function(c)
				return c:sub(1, #arg_lead) == arg_lead
			end, candidates)
		end,
		desc = "Jump to the next/prev mark in this file (needs 2+ marks); 'preview' also shows it",
	})

	research.mark = capture.mark
	research.mark_active = capture.mark_active
	research.mark_selection = capture.mark_selection
	research.mark_selection_active = capture.mark_selection_active
	research.resnippet = capture.resnippet
	research.resnippet_selection = capture.resnippet_selection
	research.start = capture.start
	research.open = nav.open
	research.open_active = nav.open_active
	research.list = nav.list
	research.delete_topic = nav.delete_topic
	research.sync_all = nav.sync_all
	research.check = stale.check
	research.jump = stale.jump
	research.peek = stale.peek
	research.yank = stale.yank
	research.view = render.open
	research.edit = render.edit
	research.delete_mark = render.delete
	research.move_mark = render.move
	research.sync_mark = render.sync
	research.toggle_snippet = render.toggle_snippet
	research.edit_mark = render.edit_mark
	research.show_snippet = render.show_snippet
	research.show_keymap_help = show_keymap_help
	research.preview_mark = annotate.preview
	research.goto_mark = annotate.goto_view
	research.jump_mark = annotate.jump
end)()

;(function --[[autocmds]]()
	local pattern = vim.fn.expand(research.config.research_dir) .. "/*/research-*.md"

	-- :mksession bakes an on-screen scratch buffer into Session.vim as a plain
	-- `edit <name>`; on reload it comes back as a real buftype, which
	-- autowriteall then writes to disk. Nothing legit creates these names
	-- this early, so wipe any match before it can be written.
	vim.api.nvim_create_autocmd("SessionLoadPost", {
		callback = guarded(function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
				if name:match("^research%-view:") or name:match("^research%-edit:") or name:match("^research:note%-") then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end
		end),
	})

	-- the WinEnter tracker itself is armed lazily by store.ensure_win_tracking(), not here.

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		pattern = pattern,
		callback = guarded(function(args)
			store.ensure_win_tracking()
			stale.check(args.buf)
			local km = research.config.keymap
			safe_keymap("n", km.jump, guarded(function()
				stale.jump(args.buf)
			end), { buffer = args.buf, silent = true, desc = "research: jump to source" })
			safe_keymap("n", km.peek, guarded(function()
				stale.peek(args.buf)
			end), { buffer = args.buf, silent = true, desc = "research: peek source (keep focus here)" })
			safe_keymap("n", km.toggle, guarded(function()
				render.open(vim.api.nvim_buf_get_name(args.buf))
			end), { buffer = args.buf, silent = true, desc = "research: switch to view" })
			safe_keymap("n", km.yank, guarded(function()
				stale.yank(args.buf)
			end), { buffer = args.buf, silent = true, desc = "research: copy mark's file:line to clipboard" })
			safe_keymap("n", km.help, guarded(show_keymap_help), {
				buffer = args.buf,
				silent = true,
				desc = "research: show keymaps",
			})

			if not vim.b[args.buf].research_autocheck then
				vim.b[args.buf].research_autocheck = true
				vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold" }, {
					buffer = args.buf,
					callback = guarded(function()
						stale.check(args.buf)
					end),
				})
			end
		end),
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = pattern,
		callback = guarded(function(args)
			-- a hand-edit's plain :w skips write_blocks/append_entry, so it
			-- wouldn't otherwise invalidate the annotate index.
			annotate.invalidate()
			stale.check(args.buf)
			local name = vim.api.nvim_buf_get_name(args.buf)
			-- deferred: swapping the buffer synchronously here races :write's own bookkeeping
			vim.schedule(guarded(function()
				render.open(name)
			end))
			if research.config.annotate_sync_on_save then
				annotate.sync_open_buffers()
			end
		end),
	})

	-- deferred so annotate_enabled never delays opening a real file.
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = guarded(function(args)
			vim.schedule(guarded(function()
				if not vim.api.nvim_buf_is_valid(args.buf) then
					return
				end
				if research.config.annotate_enabled then
					annotate.refresh(args.buf)
				end
				annotate.ensure_mark_keymaps(args.buf)
			end))
		end),
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = guarded(function(args)
			vim.schedule(guarded(function()
				annotate.auto_resync(args.buf)
				if research.config.annotate_enabled then
					annotate.refresh(args.buf)
				end
			end))
		end),
	})
end)()

-- ;(function --[[keybinds]]()
-- 	if vim.g._TEST then
-- 		return
-- 	end
-- 	keybind.research_start(":ResearchStart")
-- 	keybind.research_open(":ResearchOpen")
-- 	keybind.research_open_active(":ResearchOpenActive")
-- 	keybind.research_list(":ResearchList")
-- 	keybind.research_peek(":ResearchPeek")
-- 	keybind.research_delete(":ResearchDelete")
-- 	keybind.research_check(":ResearchCheck")
-- 	keybind.research_edit(":ResearchEdit")
--
-- 	keybind.research_mark(function()
-- 		research.mark_selection()
-- 	end)
--
-- 	keybind.research_mark_active(function()
-- 		research.mark_selection_active()
-- 	end)
--
-- 	keybind.research_resnippet(function()
-- 		research.resnippet_selection()
-- 	end)
--
-- 	keybind.research_jump_next(function()
-- 		research.jump_mark("next")
-- 	end)
--
-- 	keybind.research_jump_prev(function()
-- 		research.jump_mark("prev")
-- 	end)
--
-- 	keybind.research_jump_next_preview(function()
-- 		research.jump_mark("next", true)
-- 	end)
--
-- 	keybind.research_jump_prev_preview(function()
-- 		research.jump_mark("prev", true)
-- 	end)
--
-- 	keybind.research_sync(":ResearchSync")
-- end)()
