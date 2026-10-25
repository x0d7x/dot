local M = {}

local function center_window(width, height)
	local columns = vim.o.columns
	local lines = vim.o.lines

	return {
		row = math.floor((lines - height) / 2),
		col = math.floor((columns - width) / 2),
	}
end

local function get_files()
	return vim.fn.systemlist({
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
end

local function get_filetype(file)
	local extension = vim.fn.fnamemodify(file, ":e")

	if extension == "" then
		return ""
	end

	return vim.filetype.match({
		filename = file,
	}) or ""
end

local function read_file(file)
	if vim.fn.filereadable(file) == 0 then
		return {
			"Unable to read file:",
			file,
		}
	end

	-- Limit preview to avoid loading huge files
	local lines = vim.fn.readfile(file, "", 500)

	if #lines == 0 then
		return { "" }
	end

	return lines
end

local function picker(items, prompt, callback)
	local query = ""
	local filtered = {}

	-- Window size
	local width = math.floor(vim.o.columns * 0.80)
	local height = math.floor(vim.o.lines * 0.60)

	local position = center_window(width, height)

	-- Left / right split
	local list_width = math.floor(width * 0.55)
	local preview_width = width - list_width - 1

	local list_buf = vim.api.nvim_create_buf(false, true)
	local preview_buf = vim.api.nvim_create_buf(false, true)

	vim.bo[list_buf].buftype = "nofile"
	vim.bo[list_buf].bufhidden = "wipe"
	vim.bo[list_buf].swapfile = false

	vim.bo[preview_buf].buftype = "nofile"
	vim.bo[preview_buf].bufhidden = "wipe"
	vim.bo[preview_buf].swapfile = false

	local list_win = vim.api.nvim_open_win(list_buf, true, {
		relative = "editor",
		width = list_width,
		height = height,
		row = position.row,
		col = position.col,
		border = "rounded",
		title = " " .. prompt .. " ",
		title_pos = "center",
	})

	local preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = preview_width,
		height = height,
		row = position.row,
		col = position.col + list_width + 1,
		border = "rounded",
		title = " Preview ",
		title_pos = "center",
	})

	vim.wo[list_win].cursorline = true
	vim.wo[list_win].number = false
	vim.wo[list_win].relativenumber = false
	vim.wo[list_win].signcolumn = "no"
	vim.wo[list_win].wrap = false
	vim.wo[list_win].scrolloff = 5

	vim.wo[preview_win].number = true
	vim.wo[preview_win].relativenumber = false
	vim.wo[preview_win].signcolumn = "no"
	vim.wo[preview_win].wrap = false
	vim.wo[preview_win].cursorline = false

	local function filter()
		filtered = {}

		for _, item in ipairs(items) do
			if query == "" then
				table.insert(filtered, item)
			elseif item:lower():find(query:lower(), 1, true) then
				table.insert(filtered, item)
			end
		end

		return filtered
	end

	local function update_preview()
		if not vim.api.nvim_win_is_valid(list_win) then
			return
		end

		if not vim.api.nvim_win_is_valid(preview_win) then
			return
		end

		local current_line = vim.api.nvim_win_get_cursor(list_win)[1]
		local file = filtered[current_line]

		if not file then
			vim.bo[preview_buf].modifiable = true
			vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {})
			vim.bo[preview_buf].modifiable = false
			return
		end

		-- Expand paths such as ~/file
		file = vim.fn.expand(file)

		local lines = read_file(file)

		vim.bo[preview_buf].modifiable = true

		vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

		vim.bo[preview_buf].modifiable = false

		-- Syntax highlighting
		local filetype = get_filetype(file)

		if filetype ~= "" then
			vim.bo[preview_buf].filetype = filetype
		else
			vim.bo[preview_buf].filetype = ""
		end

		-- Make preview read-only
		vim.bo[preview_buf].modifiable = false

		-- Reset preview scroll
		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_set_cursor(preview_win, { 1, 0 })
		end
	end

	local function render()
		filter()

		vim.bo[list_buf].modifiable = true

		vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, filtered)

		vim.bo[list_buf].modifiable = false

		if #filtered > 0 then
			vim.api.nvim_win_set_cursor(list_win, { 1, 0 })
		end

		update_preview()
	end

	local function close()
		if vim.api.nvim_win_is_valid(list_win) then
			vim.api.nvim_win_close(list_win, true)
		end

		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_close(preview_win, true)
		end
	end

	local function select()
		local line = vim.api.nvim_win_get_cursor(list_win)[1]

		local item = filtered[line]

		if not item then
			return
		end

		close()

		callback(item)
	end

	local opts = {
		buffer = list_buf,
		silent = true,
		nowait = true,
	}

	vim.keymap.set("n", "<Esc>", close, opts)
	vim.keymap.set("n", "q", close, opts)

	vim.keymap.set("n", "<CR>", select, opts)

	-- Search
	vim.keymap.set("n", "/", function()
		vim.ui.input({
			prompt = "Search: ",
			default = query,
		}, function(input)
			if input == nil then
				return
			end

			query = input

			render()
		end)
	end, opts)

	local group = vim.api.nvim_create_augroup("NativePickerPreview", { clear = false })

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = list_buf,
		callback = function()
			if vim.api.nvim_win_is_valid(list_win) then
				update_preview()
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = list_buf,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(preview_win) then
				vim.api.nvim_win_close(preview_win, true)
			end

			if vim.api.nvim_buf_is_valid(preview_buf) then
				vim.api.nvim_buf_delete(preview_buf, { force = true })
			end
		end,
	})

	render()

	vim.api.nvim_set_current_win(list_win)
end

function M.oldfiles()
	local files = {}

	for _, file in ipairs(vim.v.oldfiles) do
		if vim.fn.filereadable(file) == 1 then
			table.insert(files, file)
		end
	end

	picker(files, "Recent files", function(file)
		vim.cmd("edit " .. vim.fn.fnameescape(file))
	end)
end

function M.files()
	local files = get_files()

	picker(files, "Files", function(file)
		vim.cmd("edit " .. vim.fn.fnameescape(file))
	end)
end

function M.buffers()
	local items = {}
	local lookup = {}

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
			local name = vim.api.nvim_buf_get_name(buf)

			if name ~= "" then
				local display = vim.fn.fnamemodify(name, ":~:.")

				table.insert(items, display)
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

function M.grep()
	local text = vim.fn.input("Search: ")

	if text == "" then
		return
	end

	local results = vim.fn.systemlist({
		"rg",
		"--vimgrep",
		"--smart-case",
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

	local qf_buf = vim.api.nvim_get_current_buf()
	function M.grep()
		local text = vim.fn.input("Search: ")

		if text == "" then
			return
		end

		local results = vim.fn.systemlist({
			"rg",
			"--vimgrep",
			"--smart-case",
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

		local qf_buf = vim.api.nvim_get_current_buf()
		-- vim.keymap.set("n", "<CR>", function()
		-- 	vim.cmd("cclose")
		-- 	vim.cmd("cc")
		-- end, {
		-- 	buffer = qf_buf,
		-- 	silent = true,
		-- })
	end
end

return M
