local M = {}

local MAX_PREVIEW_LINES = 500
local SEARCH_PREFIX = "  "

-- Helpers

local function display_path(path)
	return vim.fn.fnamemodify(path, ":~:.")
end

local function get_filetype(path)
	return vim.filetype.match({
		filename = path,
	}) or ""
end

local function is_binary(path)
	local ok, lines = pcall(vim.fn.readfile, path, "b", 1)

	if not ok or not lines or #lines == 0 then
		return false
	end

	return lines[1]:find("\0", 1, true) ~= nil
end

local function can_preview(path)
	if not path or path == "" then
		return false
	end

	if vim.fn.filereadable(path) ~= 1 then
		return false
	end

	if is_binary(path) then
		return false
	end

	return true
end

-- fd

local function get_files()
	if vim.fn.executable("fd") ~= 1 then
		vim.notify("fd is not installed", vim.log.levels.ERROR)

		return {}
	end

	local files = vim.fn.systemlist({
		"fd",
		"--type",
		"f",
		"--hidden",
		"--exclude",
		".git",
		"--exclude",
		"node_modules",
		"--exclude",
		".cache",
		"--exclude",
		"dist",
		"--exclude",
		"build",
	})

	if vim.v.shell_error ~= 0 then
		vim.notify("fd failed", vim.log.levels.ERROR)

		return {}
	end

	return files
end

-- Picker

local function picker(source, prompt, callback)
	local closed = false
	local searching = false
	local query = ""

	local items = {}
	local display_items = {}
	local lookup = {}

	local search_buf
	local picker_buf
	local preview_buf

	local search_win
	local picker_win
	local preview_win

	local selection_ns = vim.api.nvim_create_namespace("NativeFinderSelection")

	-- Source

	local function get_items()
		local result

		if type(source) == "function" then
			result = source(query) or {}
		elseif query == "" then
			result = source or {}
		else
			result = vim.fn.matchfuzzy(source or {}, query)
		end

		return result
	end

	-- Rebuild results

	local function rebuild_items()
		items = get_items()

		display_items = {}
		lookup = {}

		for _, item in ipairs(items) do
			local display = display_path(item)

			display_items[#display_items + 1] = display
			lookup[display] = item
		end
	end

	-- Dimensions

	local total_width = math.floor(vim.o.columns * 0.80)
	local total_height = math.floor(vim.o.lines * 0.60)

	local picker_width = math.floor(total_width * 0.45)
	local preview_width = total_width - picker_width - 1

	local row = math.floor((vim.o.lines - total_height) / 2)

	local col = math.floor((vim.o.columns - total_width) / 2)

	-- Buffers

	search_buf = vim.api.nvim_create_buf(false, true)
	picker_buf = vim.api.nvim_create_buf(false, true)
	preview_buf = vim.api.nvim_create_buf(false, true)

	for _, buf in ipairs({
		search_buf,
		picker_buf,
		preview_buf,
	}) do
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
		vim.bo[buf].undofile = false
	end

	-- Search buffer is editable.
	vim.bo[search_buf].modifiable = true

	-- Results and preview are read-only.
	vim.bo[picker_buf].modifiable = false
	vim.bo[preview_buf].modifiable = false

	-- Mark the search buffer so completion plugins can ignore it.
	vim.b[search_buf].completion_disabled = true

	-- Windows

	search_win = vim.api.nvim_open_win(search_buf, true, {
		relative = "editor",
		width = total_width - 2,
		height = 1,
		row = row,
		col = col + 1,
		style = "minimal",
		border = "rounded",
		title = " Search ",
		title_pos = "left",
	})

	picker_win = vim.api.nvim_open_win(picker_buf, false, {
		relative = "editor",
		width = picker_width,
		height = total_height - 2,
		row = row + 2,
		col = col,
		border = "rounded",
		title = " " .. prompt .. " ",
		title_pos = "center",
	})

	preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = preview_width,
		height = total_height - 2,
		row = row + 2,
		col = col + picker_width + 1,
		border = "rounded",
		title = " Preview ",
		title_pos = "center",
	})

	-- Window options

	-- Search
	vim.wo[search_win].number = false
	vim.wo[search_win].relativenumber = false
	vim.wo[search_win].cursorline = false
	vim.wo[search_win].signcolumn = "no"
	vim.wo[search_win].wrap = false
	vim.wo[search_win].spell = false

	-- Results
	vim.wo[picker_win].number = false
	vim.wo[picker_win].relativenumber = false
	vim.wo[picker_win].cursorline = true
	vim.wo[picker_win].signcolumn = "no"
	vim.wo[picker_win].wrap = false
	vim.wo[picker_win].scrolloff = 5

	-- Preview
	vim.wo[preview_win].number = true
	vim.wo[preview_win].relativenumber = false
	vim.wo[preview_win].signcolumn = "no"
	vim.wo[preview_win].wrap = false
	vim.wo[preview_win].cursorline = false
	vim.wo[preview_win].scrolloff = 5

	-- Search buffer

	vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, { SEARCH_PREFIX })

	-- Close

	local function close()
		if closed then
			return
		end

		closed = true

		local windows = {
			search_win,
			picker_win,
			preview_win,
		}

		for _, win in ipairs(windows) do
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end

		local buffers = {
			search_buf,
			picker_buf,
			preview_buf,
		}

		for _, buf in ipairs(buffers) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end

	-- Preview

	local function update_selection_highlight()
		if not vim.api.nvim_buf_is_valid(picker_buf) then
			return
		end

		vim.api.nvim_buf_clear_namespace(picker_buf, selection_ns, 0, -1)

		if #display_items == 0 then
			return
		end

		if not vim.api.nvim_win_is_valid(picker_win) then
			return
		end

		local line = vim.api.nvim_win_get_cursor(picker_win)[1]

		if line < 1 or line > #display_items then
			return
		end

		vim.api.nvim_buf_add_highlight(picker_buf, selection_ns, "Visual", line - 1, 0, -1)
	end

	local function set_preview_message(message)
		if not vim.api.nvim_buf_is_valid(preview_buf) then
			return
		end

		vim.bo[preview_buf].modifiable = true

		vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
			"",
			"  " .. message,
		})

		vim.bo[preview_buf].modifiable = false
		vim.bo[preview_buf].filetype = ""
	end

	local function update_preview()
		if closed then
			return
		end

		if not vim.api.nvim_win_is_valid(picker_win) then
			return
		end

		local count = #display_items

		if count == 0 then
			set_preview_message("No matches.")
			return
		end

		local cursor = vim.api.nvim_win_get_cursor(picker_win)

		local index = cursor[1]

		local display = display_items[index]

		if not display then
			set_preview_message("No file selected.")
			return
		end

		local path = lookup[display]

		if not path then
			set_preview_message("No file selected.")
			return
		end

		if not can_preview(path) then
			set_preview_message("Binary or unreadable file.")

			return
		end

		local ok, lines = pcall(vim.fn.readfile, path, "", MAX_PREVIEW_LINES)

		if not ok then
			set_preview_message("Unable to read file.")

			return
		end

		if #lines == 0 then
			lines = { "" }
		end

		vim.bo[preview_buf].modifiable = true

		vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

		vim.bo[preview_buf].modifiable = false

		vim.bo[preview_buf].filetype = get_filetype(path)

		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_set_cursor(preview_win, { 1, 0 })
		end
	end

	-- Render

	local function render()
		if closed then
			return
		end

		rebuild_items()

		vim.bo[picker_buf].modifiable = true

		vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, display_items)

		vim.bo[picker_buf].modifiable = false

		if #display_items == 0 then
			update_selection_highlight()
			set_preview_message("No matches.")
			return
		end

		if vim.api.nvim_win_is_valid(picker_win) then
			vim.api.nvim_win_set_cursor(picker_win, { 1, 0 })
		end

		update_selection_highlight()
		update_preview()
	end

	-- Move result

	local function move_result(delta)
		if closed then
			return
		end

		if not vim.api.nvim_win_is_valid(picker_win) then
			return
		end

		local count = #display_items

		if count == 0 then
			return
		end

		local current = vim.api.nvim_win_get_cursor(picker_win)[1]

		local next_line = math.max(1, math.min(current + delta, count))

		vim.api.nvim_win_set_cursor(picker_win, {
			next_line,
			0,
		})

		update_selection_highlight()
		update_preview()
	end

	-- Focus search

	local function focus_search()
		if closed then
			return
		end

		searching = true

		if not vim.api.nvim_win_is_valid(search_win) then
			return
		end

		vim.api.nvim_set_current_win(search_win)

		local line = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)[1] or SEARCH_PREFIX

		local column = math.max(#SEARCH_PREFIX, #line)

		vim.api.nvim_win_set_cursor(search_win, {
			1,
			column,
		})

		vim.cmd("startinsert")
	end

	-- Focus results

	local function focus_results()
		if closed then
			return
		end

		searching = false

		if not vim.api.nvim_win_is_valid(picker_win) then
			return
		end

		vim.api.nvim_set_current_win(picker_win)

		vim.cmd("stopinsert")

		update_preview()
	end

	-- Select

	local function select()
		if closed then
			return
		end

		-- If currently searching, Enter first returns to results.
		if searching then
			focus_results()
			return
		end

		if not vim.api.nvim_win_is_valid(picker_win) then
			return
		end

		local line = vim.api.nvim_win_get_cursor(picker_win)[1]

		local display = display_items[line]

		if not display then
			return
		end

		local item = lookup[display]

		if not item then
			return
		end

		close()

		callback(item)
	end

	-- Search query

	local function get_query()
		local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)

		local line = lines[1] or ""

		if vim.startswith(line, SEARCH_PREFIX) then
			return line:sub(#SEARCH_PREFIX + 1)
		end

		return line
	end

	local function update_query()
		if closed then
			return
		end

		local new_query = get_query()

		if new_query == query then
			return
		end

		query = new_query

		render()
	end

	-- Close mappings
	--
	-- q closes from ANY picker window in NORMAL mode.

	local function map_close(buf)
		vim.keymap.set("n", "q", close, {
			buffer = buf,
			silent = true,
			nowait = true,
			desc = "Close picker",
		})
	end

	map_close(search_buf)
	map_close(picker_buf)
	map_close(preview_buf)

	-- Search mappings

	-- Escape from Insert mode -> return to results.
	vim.keymap.set("n", "<Esc>", function()
		focus_results()
	end, {
		buffer = search_buf,
		silent = true,
		nowait = true,
		desc = "Return to picker",
	})
	vim.keymap.set("i", "<Esc>", function()
		focus_results()
	end, {
		buffer = search_buf,
		silent = true,
		nowait = true,
		desc = "Return to picker",
	})

	-- Enter from Insert mode -> return to results.
	vim.keymap.set("i", "<CR>", function()
		focus_results()
	end, {
		buffer = search_buf,
		silent = true,
		nowait = true,
		desc = "Return to picker",
	})

	-- Ctrl-n -> next result while staying in Insert mode.
	vim.keymap.set("i", "<C-n>", function()
		move_result(1)

		if vim.api.nvim_win_is_valid(search_win) then
			vim.api.nvim_set_current_win(search_win)
			vim.cmd("startinsert")
		end
	end, {
		buffer = search_buf,
		silent = true,
		nowait = true,
		desc = "Next result",
	})

	-- Ctrl-p -> previous result while staying in Insert mode.
	vim.keymap.set("i", "<C-p>", function()
		move_result(-1)

		if vim.api.nvim_win_is_valid(search_win) then
			vim.api.nvim_set_current_win(search_win)
			vim.cmd("startinsert")
		end
	end, {
		buffer = search_buf,
		silent = true,
		nowait = true,
		desc = "Previous result",
	})

	-- Picker mappings

	-- Normal mode j/k are native Vim movement.
	--
	-- q is mapped above and closes the picker.

	-- Enter -> open selected item.
	vim.keymap.set("n", "<CR>", select, {
		buffer = picker_buf,
		silent = true,
		nowait = true,
		desc = "Open selected",
	})

	-- / -> search.
	vim.keymap.set("n", "/", focus_search, {
		buffer = picker_buf,
		silent = true,
		nowait = true,
		desc = "Search",
	})

	-- Ctrl-d -> scroll preview down.
	vim.keymap.set("n", "<C-d>", function()
		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_call(preview_win, function()
				vim.cmd("normal! <C-d>")
			end)
		end
	end, {
		buffer = picker_buf,
		silent = true,
		nowait = true,
		desc = "Scroll preview down",
	})

	-- Ctrl-u -> scroll preview up.
	vim.keymap.set("n", "<C-u>", function()
		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_call(preview_win, function()
				vim.cmd("normal! <C-u>")
			end)
		end
	end, {
		buffer = picker_buf,
		silent = true,
		nowait = true,
		desc = "Scroll preview up",
	})

	-- Preview mappings

	-- Enter from preview -> select current item.
	vim.keymap.set("n", "<CR>", select, {
		buffer = preview_buf,
		silent = true,
		nowait = true,
		desc = "Open selected",
	})

	-- q is already mapped above.
	-- Escape also closes from preview.
	vim.keymap.set("n", "<Esc>", close, {
		buffer = preview_buf,
		silent = true,
		nowait = true,
		desc = "Close picker",
	})

	-- Search autocmd

	local search_group = vim.api.nvim_create_augroup("NativeFinderSearch", {
		clear = false,
	})

	vim.api.nvim_create_autocmd({
		"TextChanged",
		"TextChangedI",
	}, {
		group = search_group,
		buffer = search_buf,
		callback = function()
			update_query()
		end,
	})

	-- Cursor movement -> update preview

	local cursor_group = vim.api.nvim_create_augroup("NativeFinderPreview", {
		clear = false,
	})

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = cursor_group,
		buffer = picker_buf,
		callback = function()
			update_selection_highlight()
			update_preview()
		end,
	})

	-- Initial render

	render()

	-- Start directly in the search bar.
	vim.schedule(function()
		if closed then
			return
		end

		if not vim.api.nvim_win_is_valid(search_win) then
			return
		end

		vim.api.nvim_set_current_win(search_win)

		local line = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)[1] or SEARCH_PREFIX

		vim.api.nvim_win_set_cursor(search_win, {
			1,
			#line,
		})

		searching = true

		vim.cmd("startinsert")
	end)
end

-- Files

function M.files()
	local files = get_files()

	picker(files, "Files", function(file)
		vim.cmd("edit " .. vim.fn.fnameescape(file))
	end)
end

-- Recent files

function M.oldfiles()
	local files = {}

	for _, file in ipairs(vim.v.oldfiles) do
		if vim.fn.filereadable(file) == 1 then
			files[#files + 1] = file
		end
	end

	picker(files, "Recent files", function(file)
		vim.cmd("edit " .. vim.fn.fnameescape(file))
	end)
end

-- Buffers

function M.buffers()
	local items = {}
	local lookup = {}

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
			local name = vim.api.nvim_buf_get_name(buf)

			if name ~= "" then
				local display = display_path(name)

				items[#items + 1] = display
				lookup[display] = buf
			end
		end
	end

	picker(items, "Buffers", function(item)
		local buf = lookup[item]

		if buf and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_set_current_buf(buf)
		end
	end)
end

-- Grep

function M.grep()
	if vim.fn.executable("rg") ~= 1 then
		vim.notify("rg is not installed", vim.log.levels.ERROR)

		return
	end

	local text = vim.fn.input("Search: ")

	if text == "" then
		return
	end

	local results = vim.fn.systemlist({
		"rg",
		"--vimgrep",
		"--smart-case",
		"--hidden",
		"--glob",
		"!.git",
		"--glob",
		"!node_modules",
		"--glob",
		"!.cache",
		"--glob",
		"!dist",
		"--glob",
		"!build",
		"--",
		text,
		".",
	})

	if #results == 0 then
		vim.notify("No matches found", vim.log.levels.INFO)

		return
	end

	vim.fn.setqflist({}, " ", {
		title = "rg: " .. text,
		lines = results,
		efm = "%f:%l:%c:%m",
	})

	vim.cmd("copen")
end

return M
