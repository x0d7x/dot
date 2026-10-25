-- winjump.lua: label every window, press the label to jump there.
--
_G.winjump = _G.winjump or {}
local winjump = _G.winjump

local label = {}
local pick = {}

local function guarded(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			vim.notify("winjump: internal error: " .. tostring(err), vim.log.levels.ERROR)
		end
	end
end

local function safe_keymap(mode, lhs, rhs, opts)
	if not lhs or lhs == "" then
		return
	end
	vim.keymap.set(mode, lhs, rhs, opts)
end
(function --[[config]]()
	-- Every gap / margin / offset below takes a number for both axes or
	-- { row = n, col = n }.
	winjump.config = {
		-- names the options table to read: one label per window with "edge",
		-- "corner" or "window-center" (alias "center"), or one map of every window
		-- with "editor-center" or "cursor"
		placement = "editor-center",

		edge = { gap = 1 }, -- window corner facing the screen centre
		corner = { gap = 1 }, -- window's top-left
		window_center = {}, -- middle of the window; nothing to tune

		-- a single float shaped like the layout, in the middle of the editor
		editor_center = {
			gap = 1, -- cell pitch
			-- how a cell gets its column:
			--   "layout": scaled from the window's own position, so widths show
			--   "compact": packed, but a window keeps the column of the one above
			--     it when they share a start column
			--   "packed": packed left to right, position ignored
			align = "compact",
			scale = 0.35, -- "layout" only: map width as a share of vim.o.columns
			-- any hyphenated mix of top / bottom / left / right / center
			-- ("top-left", "top"); a missing axis centres. Or centre the map on a
			-- separator crossing, following resizes: "split" takes the crossing
			-- nearest the middle of the editor, "split-focus" the one nearest the
			-- cursor. A layout with no crossing snaps each axis on its own.
			-- "cursor" behaves like the placement of that name.
			anchor = "split",
			margin = 0, -- cells from the screen edge, edge anchors only
		},

		-- the same map, placed at the cursor and flipped away from whichever
		-- screen edge it would otherwise run past
		cursor = {
			gap = 1,
			align = "compact",
			scale = 0.35,
			offset = 0, -- cells from the cursor; 0 is its own row and column,
			-- negatives pull the map up and left
		},

		-- how many times taller than wide a terminal cell is. Only used to judge
		-- which separator crossing is nearest, so that 1 row counts as the
		-- vertical distance it actually looks like. 2 suits most fonts.
		cell_aspect = 2,
		chars = "12345678", -- pairs up (aa, as, ad, ...) when there are more windows
		format = " %s ",
		border = "single", -- explicit: floats otherwise inherit the global 'winborder'
		border_hl = "WinJumpBorder", -- highlight group for the border; nil leaves it on FloatBorder
		timeout = 2000, -- ms to wait for a key before the labels vanish; 0 waits forever
		skip_current = true,
		auto_jump_single = true, -- one candidate: jump without prompting
		winblend = 0,
		zindex = 300,
		ignore_filetypes = {},
		ignore_buftypes = {},
		keymap = { jump = "<C-.>" },
	}
end)();
(function --[[options]]()
	local KEY = {
		["edge"] = "edge",
		["corner"] = "corner",
		["center"] = "window_center",
		["window-center"] = "window_center",
		["editor-center"] = "editor_center",
		["cursor"] = "cursor",
	}

	-- options table of the placement in use; readers supply their own defaults,
	-- so an unknown placement degrades instead of erroring
	function winjump.opts()
		return winjump.config[KEY[winjump.config.placement or ""] or ""] or {}
	end
end)();
(function --[[highlight]]()
	local function define()
		vim.api.nvim_set_hl(0, "WinJumpLabel", { link = "Keyword", default = true })
		vim.api.nvim_set_hl(0, "WinJumpBorder", { link = "WinJumpLabel", default = true })
		-- vim.api.nvim_set_hl(0, "WinJumpBorder", { fg = "#64342c", default = true })
		-- the window you are already in: shown so the map keeps its shape
		vim.api.nvim_set_hl(0, "WinJumpCurrent", { link = "Comment", default = true })
		vim.api.nvim_set_hl(0, "WinJumpGrid", { link = "NormalFloat", default = true })
	end
	define()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("winjump_hl", { clear = true }),
		callback = guarded(define),
		desc = "WinJump: keep the label highlight defined",
	})
end)();
(function --[[label]]()
	local open = {}
	local ns = vim.api.nvim_create_namespace("winjump")

	function label.clear()
		for _, w in ipairs(open) do
			if vim.api.nvim_win_is_valid(w) then
				pcall(vim.api.nvim_win_close, w, true)
			end
		end
		open = {}
	end

	-- number for both axes or { row = n, col = n }; floor clamps negatives away
	-- for everything except cursor_offsets, where they are meaningful
	local function pair_of(v, floor)
		local r, c
		if type(v) == "table" then
			r, c = math.floor(tonumber(v.row) or 0), math.floor(tonumber(v.col) or 0)
		else
			local n = math.floor(tonumber(v) or 0)
			r, c = n, n
		end
		if floor then
			return math.max(0, r), math.max(0, c)
		end
		return r, c
	end

	local function gaps()
		return pair_of(winjump.opts().gap, true)
	end

	local function margins()
		return pair_of(winjump.opts().margin, true)
	end

	-- Crossing nearest (mid_r, mid_c). A window corner is a real crossing: the
	-- separator along that edge meets the one along the adjacent edge there, so
	-- taking corners avoids pairing a row from one divider with a column from a
	-- different one, which need not intersect at all. Coordinates on the screen
	-- edge are not separators and are dropped.
	--
	-- With no crossing at all -- a single row or column of windows -- each axis
	-- snaps on its own and keeps the reference coordinate where it has nothing
	-- to snap to.
	local function split_point(wins, usable_h, mid_r, mid_c)
		-- rows weigh more than columns: cells are taller than they are wide, so
		-- equal cell counts are not equal distances on screen
		local aspect = math.max(0.1, tonumber(winjump.config.cell_aspect) or 2)
		local best_r, best_c, best_d = nil, nil, math.huge
		for _, w in ipairs(wins or {}) do
			local pos = vim.api.nvim_win_get_position(w)
			local rows = { pos[1], pos[1] + vim.api.nvim_win_get_height(w) }
			local cols = { pos[2], pos[2] + vim.api.nvim_win_get_width(w) }
			for _, r in ipairs(rows) do
				for _, c in ipairs(cols) do
					if r > 0 and r < usable_h and c > 0 and c < vim.o.columns then
						local d = math.abs(r - mid_r) * aspect + math.abs(c - mid_c)
						if d < best_d then
							best_d, best_r, best_c = d, r, c
						end
					end
				end
			end
		end
		if best_r then
			return best_r, best_c
		end

		local fb_r, fb_c = mid_r, mid_c
		local dr, dc = math.huge, math.huge
		for _, w in ipairs(wins or {}) do
			local pos = vim.api.nvim_win_get_position(w)
			local bottom = pos[1] + vim.api.nvim_win_get_height(w)
			local right = pos[2] + vim.api.nvim_win_get_width(w)
			if bottom > 0 and bottom < usable_h and math.abs(bottom - mid_r) < dr then
				dr, fb_r = math.abs(bottom - mid_r), bottom
			end
			if right > 0 and right < vim.o.columns and math.abs(right - mid_c) < dc then
				dc, fb_c = math.abs(right - mid_c), right
			end
		end
		return fb_r, fb_c
	end

	local function cursor_offsets()
		return pair_of(winjump.opts().offset, false)
	end

	-- border_hl nil leaves the border on FloatBorder
	local function winhl(normal_group)
		local hl = winjump.config.border_hl
		if hl and hl ~= "" then
			return normal_group .. ",FloatBorder:" .. hl
		end
		return normal_group
	end

	-- Screen cell of the cursor, 0-based. screenpos accounts for wrap, folds and
	-- the window's own offset; it reports row 0 when the position is off-screen.
	local function cursor_cell()
		local p = vim.fn.screenpos(0, vim.fn.line("."), vim.fn.col("."))
		if not p or p.row == 0 then
			return math.floor((vim.o.lines - vim.o.cmdheight - 1) / 2), math.floor(vim.o.columns / 2)
		end
		return p.row - 1, p.col - 1
	end

	-- Top-left corner for a width x height map. A border draws outside the float,
	-- so it counts against the margin. Only the edge anchors read `margin`;
	-- "cursor" reads `offset` and "split" needs neither.
	local function anchor_at(width, height, wins)
		local anchor = tostring(winjump.opts().anchor or "")
		local vert, horz = "center", "center"
		for part in anchor:gmatch("[^-]+") do
			if part == "top" or part == "bottom" then
				vert = part
			elseif part == "left" or part == "right" then
				horz = part
			end
		end

		-- a nil config border means the float inherits the global 'winborder'
		local border = winjump.config.border or vim.o.winborder
		local ring = (border and border ~= "" and border ~= "none") and 1 or 0
		local margin_row, margin_col = margins()
		margin_row, margin_col = margin_row + ring, margin_col + ring
		-- the cmdline and the last statusline are not ours to draw on
		local usable_h = vim.o.lines - vim.o.cmdheight - 1

		if winjump.config.placement == "cursor" or anchor:find("cursor") then
			-- down-right of the cursor, flipped to the other side of it when that
			-- would run past the edge, then clamped as a last resort
			local cr, cc = cursor_cell()
			local off_row, off_col = cursor_offsets()
			local row = cr + off_row
			if row + height + ring > usable_h then
				row = cr - height - off_row
			end
			local col = cc + off_col
			if col + width + ring > vim.o.columns then
				col = cc - width - off_col
			end
			return math.max(ring, math.min(row, usable_h - height - ring)),
				math.max(ring, math.min(col, vim.o.columns - width - ring))
		end

		if anchor:find("split") then
			-- "split" measures from the middle of the editor, "split-focus" from
			-- the cursor
			local mid_r, mid_c = usable_h / 2, vim.o.columns / 2
			if anchor:find("focus") then
				mid_r, mid_c = cursor_cell()
			end
			local pr, pc = split_point(wins, usable_h, mid_r, mid_c)
			local row = math.floor(pr - height / 2)
			local col = math.floor(pc - width / 2)
			return math.max(ring, math.min(row, usable_h - height - ring)),
				math.max(ring, math.min(col, vim.o.columns - width - ring))
		end

		local row
		if vert == "top" then
			row = margin_row
		elseif vert == "bottom" then
			row = usable_h - height - margin_row
		else
			row = math.floor((usable_h - height) / 2)
		end

		local col
		if horz == "left" then
			col = margin_col
		elseif horz == "right" then
			col = vim.o.columns - width - margin_col
		else
			col = math.floor((vim.o.columns - width) / 2)
		end

		return math.max(0, row), math.max(0, col)
	end

	local function position(win, text_w)
		local pos = vim.api.nvim_win_get_position(win)
		local top, left = pos[1], pos[2]
		local w = vim.api.nvim_win_get_width(win)
		local h = vim.api.nvim_win_get_height(win)
		local placement = winjump.config.placement
		local gap_row, gap_col = gaps()
		local row, col = top, left
		local toward_right, toward_bottom = false, false

		if placement == "window-center" or placement == "center" then
			row = top + math.floor(h / 2)
			col = left + math.floor((w - text_w) / 2)
		else
			toward_right = placement ~= "corner" and left + w / 2 < vim.o.columns / 2
			toward_bottom = placement ~= "corner" and top + h / 2 < vim.o.lines / 2
			col = toward_right and (left + w - text_w - gap_col) or (left + gap_col)
			row = toward_bottom and (top + h - 1 - gap_row) or (top + gap_row)
		end

		-- gap must never push the label out of its own window
		row = math.min(math.max(row, top), top + h - 1)
		col = math.min(math.max(col, left), left + math.max(0, w - text_w))
		row = math.max(0, math.min(row, vim.o.lines - 2))
		col = math.max(0, math.min(col, vim.o.columns - text_w))
		return row,
			col,
			{
				top = top,
				left = left,
				w = w,
				h = h,
				gap_row = gap_row,
				gap_col = gap_col,
				toward_right = toward_right,
				toward_bottom = toward_bottom,
			}
	end
	label.position = position

	-- Rows are always one per distinct window start row, so a window spanning
	-- several rows gets one cell on its topmost. Columns follow `align`.
	-- cells[win] = { row, col }, both 0-based offsets inside the map.
	function label.grid_layout(wins, cell_text_w)
		local rows, seen_r = {}, {}
		for _, w in ipairs(wins) do
			local pos = vim.api.nvim_win_get_position(w)
			if not seen_r[pos[1]] then
				seen_r[pos[1]] = true
				table.insert(rows, pos[1])
			end
		end
		table.sort(rows)

		local rank_r = {}
		for i, v in ipairs(rows) do
			rank_r[v] = i - 1
		end

		local gap_row, gap_col = gaps()
		local cell_w = cell_text_w + gap_col
		local cell_h = 1 + gap_row

		-- rows of windows sharing a start row, left to right
		local per_row = {}
		for _, w in ipairs(wins) do
			local pos = vim.api.nvim_win_get_position(w)
			local r = rank_r[pos[1]]
			per_row[r] = per_row[r] or {}
			table.insert(per_row[r], { win = w, src = pos[2] })
		end
		for _, list in pairs(per_row) do
			table.sort(list, function(a, b)
				return a.src < b.src
			end)
		end

		local mode = winjump.opts().align
		local cells = {}

		if mode == "layout" then
			-- Each label keeps its window's share of the screen. Cells are then
			-- pushed apart to cell_w, and an overflowing row is pulled back in
			-- from the right.
			local scale = math.min(math.max(tonumber(winjump.opts().scale) or 0.35, 0.05), 1)
			local map_w = math.max(cell_w, math.floor(vim.o.columns * scale))
			for r, list in pairs(per_row) do
				local minc = 0
				for _, e in ipairs(list) do
					e.col = math.max(math.floor(e.src * map_w / vim.o.columns), minc)
					minc = e.col + cell_w
				end
				local over = list[#list].col + cell_text_w - map_w
				for i = #list, 1, -1 do
					if over <= 0 then
						break
					end
					local moved = math.min(over, list[i].col)
					list[i].col = list[i].col - moved
					over = (i > 1) and (list[i - 1].col + cell_w - list[i].col) or 0
				end
				for _, e in ipairs(list) do
					cells[e.win] = { row = r * cell_h, col = e.col }
				end
			end
		elseif mode == "packed" then
			for r, list in pairs(per_row) do
				for i, e in ipairs(list) do
					cells[e.win] = { row = r * cell_h, col = (i - 1) * cell_w }
				end
			end
		else -- "compact"
			-- Indices go out row by row, top to bottom. A start column that already
			-- has one reuses it, so a window stays under the one it shares a split
			-- with; anything else takes the next free index, so no row carries a
			-- hole for a column it does not use.
			local index_of, order = {}, {}
			for r in pairs(per_row) do
				table.insert(order, r)
			end
			table.sort(order)
			for _, r in ipairs(order) do
				local cursor = 0
				for _, e in ipairs(per_row[r]) do
					local idx = index_of[e.src]
					if not idx or idx < cursor then
						idx = cursor
					end
					index_of[e.src] = idx
					cursor = idx + 1
					cells[e.win] = { row = r * cell_h, col = idx * cell_w }
				end
			end
		end

		local width = 0
		for _, cell in pairs(cells) do
			width = math.max(width, cell.col + cell_text_w)
		end
		local height = #rows * cell_h - gap_row
		local top, left = anchor_at(width, height, wins)
		return {
			cells = cells,
			width = width,
			height = height,
			top = top,
			left = left,
		}
	end

	-- One float for the whole map: separate floats make the gaps read as holes
	-- in the screen rather than as the layout's shape. Labels are ASCII, so byte
	-- and display offsets agree here.
	function label.show_grid(wins, texts, current)
		local cell_text_w = 1
		for _, t in pairs(texts) do
			cell_text_w = math.max(cell_text_w, vim.fn.strdisplaywidth(t))
		end
		local g = label.grid_layout(wins, cell_text_w)

		local lines = {}
		for r = 1, g.height do
			lines[r] = string.rep(" ", g.width)
		end
		local marks = {}
		for _, w in ipairs(wins) do
			local cell = g.cells[w]
			local text = texts[w]
			local r = cell.row + 1
			local c = cell.col
			lines[r] = lines[r]:sub(1, c) .. text .. lines[r]:sub(c + #text + 1)
			table.insert(marks, {
				row = r - 1,
				col = c,
				len = #text,
				hl = w == current and "WinJumpCurrent" or "WinJumpLabel",
			})
		end

		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		for _, m in ipairs(marks) do
			vim.api.nvim_buf_set_extmark(buf, ns, m.row, m.col, {
				end_col = m.col + m.len,
				hl_group = m.hl,
			})
		end

		local float = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = g.top,
			col = g.left,
			width = g.width,
			height = g.height,
			style = "minimal",
			border = winjump.config.border,
			focusable = false,
			noautocmd = true,
			zindex = winjump.config.zindex,
		})
		table.insert(open, float)
		vim.wo[float].winhighlight = winhl("Normal:WinJumpGrid")
		vim.wo[float].winblend = winjump.config.winblend
	end

	function label.show(win, text)
		local text_w = math.max(1, vim.fn.strdisplaywidth(text))
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

		local row, col = position(win, text_w)
		local float = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = row,
			col = col,
			width = text_w,
			height = 1,
			style = "minimal",
			border = winjump.config.border,
			focusable = false,
			noautocmd = true,
			zindex = winjump.config.zindex,
		})
		-- registered before anything else can throw, so clear() always finds it
		table.insert(open, float)
		vim.wo[float].winhighlight = winhl("Normal:WinJumpLabel")
		vim.wo[float].winblend = winjump.config.winblend
	end
end)();
(function --[[pick]]()
	-- keep_current overrides skip_current: the grid needs every window or its
	-- shape stops matching the layout
	local function candidates(keep_current)
		local cfg = winjump.config
		local cur = vim.api.nvim_get_current_win()
		local out = {}
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if
				vim.api.nvim_win_is_valid(w)
				and vim.api.nvim_win_get_config(w).relative == ""
				and not (cfg.skip_current and not keep_current and w == cur)
			then
				local buf = vim.api.nvim_win_get_buf(w)
				if
					not vim.tbl_contains(cfg.ignore_buftypes, vim.bo[buf].buftype)
					and not vim.tbl_contains(cfg.ignore_filetypes, vim.bo[buf].filetype)
				then
					table.insert(out, w)
				end
			end
		end
		table.sort(out, function(a, b)
			local pa = vim.api.nvim_win_get_position(a)
			local pb = vim.api.nvim_win_get_position(b)
			if pa[1] ~= pb[1] then
				return pa[1] < pb[1]
			end
			return pa[2] < pb[2]
		end)
		return out
	end

	local function make_labels(n)
		local chars = winjump.config.chars
		local out = {}
		if #chars == 0 then
			return out
		end
		if n <= #chars then
			for i = 1, n do
				out[i] = chars:sub(i, i)
			end
			return out
		end
		for a = 1, #chars do
			for b = 1, #chars do
				if #out >= n then
					return out
				end
				table.insert(out, chars:sub(a, a) .. chars:sub(b, b))
			end
		end
		return out
	end

	-- nil on <Esc>, <C-c> or config.timeout elapsing
	local function getkey()
		local timeout = winjump.config.timeout
		if timeout and timeout > 0 then
			local waited = vim.fn.wait(timeout, function()
				return vim.fn.getchar(1) ~= 0
			end, 20)
			if waited ~= 0 then
				return nil
			end
		end
		local ok, ch = pcall(vim.fn.getcharstr)
		if not ok or ch == "" or ch == "\27" then
			return nil
		end
		return ch
	end

	-- nil on cancel or a key no label starts with
	local function read(map, maxlen)
		local typed = ""
		while #typed < maxlen do
			vim.cmd("redraw")
			local ch = getkey()
			if not ch then
				return nil
			end
			typed = typed .. ch
			if map[typed] then
				return map[typed]
			end
			local prefix = false
			for key in pairs(map) do
				if key:sub(1, #typed) == typed then
					prefix = true
					break
				end
			end
			if not prefix then
				return nil
			end
		end
		return nil
	end

	function pick.jump()
		local placement = winjump.config.placement
		local grid_mode = placement == "editor-center" or placement == "cursor"
		local current = vim.api.nvim_get_current_win()
		local wins = candidates(grid_mode)
		if #wins == 0 or (grid_mode and #wins < 2) then
			return
		end
		if not grid_mode and #wins == 1 and winjump.config.auto_jump_single then
			vim.api.nvim_set_current_win(wins[1])
			return
		end

		local labels = make_labels(#wins)
		if #labels < #wins then
			vim.notify(
				string.format("winjump: winjump.config.chars cannot label %d windows", #wins),
				vim.log.levels.ERROR
			)
			return
		end

		local target
		-- labels are torn down whatever happens in here
		local ok, err = pcall(function()
			local map, texts, maxlen = {}, {}, 0
			for i, w in ipairs(wins) do
				map[labels[i]] = w
				maxlen = math.max(maxlen, #labels[i])
				texts[w] = string.format(winjump.config.format, labels[i])
			end

			if grid_mode then
				label.show_grid(wins, texts, current)
			else
				for _, w in ipairs(wins) do
					label.show(w, texts[w])
				end
			end
			target = read(map, maxlen)
		end)

		label.clear()
		vim.cmd("redraw")
		if not ok then
			error(err)
		end
		if target and vim.api.nvim_win_is_valid(target) then
			vim.api.nvim_set_current_win(target)
		end
	end
end)();
(function --[[commands]]()
	vim.api.nvim_create_user_command("WinJump", guarded(pick.jump), {
		desc = "WinJump: label every window and jump to the one you pick",
	})
	vim.api.nvim_create_user_command(
		"WinJumpDebug",
		guarded(function()
			local cfg = winjump.config
			local text_w = vim.fn.strdisplaywidth(string.format(cfg.format, "a"))
			local lines = {
				{
					string.format(
						"editor %dx%d  placement=%s %s label_w=%d",
						vim.o.columns,
						vim.o.lines,
						cfg.placement,
						vim.inspect(winjump.opts()):gsub("%s+", " "),
						text_w
					),
					"Title",
				},
			}
			local wins = {}
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
					table.insert(wins, win)
				end
			end
			local grid_mode = cfg.placement == "editor-center" or cfg.placement == "cursor"
			local grid = grid_mode and label.grid_layout(wins, text_w) or nil

			for _, win in ipairs(wins) do
				local row, col, i = label.position(win, text_w)
				if grid then
					local cell = grid.cells[win]
					row = grid.top + cell.row
					col = grid.left + cell.col
				end
				table.insert(lines, {
					string.format(
						"\nwin %-5d rect row %d..%d col %d..%d   label row=%d col=%d..%d   right=%s bottom=%s",
						win,
						i.top,
						i.top + i.h - 1,
						i.left,
						i.left + i.w - 1,
						row,
						col,
						col + text_w - 1,
						tostring(i.toward_right),
						tostring(i.toward_bottom)
					),
					"Normal",
				})
			end
			vim.api.nvim_echo(lines, true, {})
		end),
		{
			desc = "WinJump: report each window's rect and its computed label position",
		}
	)
end)();
(function --[[keybinds]]()
	safe_keymap({ "n", "t" }, winjump.config.keymap.jump, guarded(pick.jump), {
		silent = true,
		desc = "WinJump: jump to a labelled window",
	})
end)()
