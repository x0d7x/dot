if vim.fn.argc() > 0 then
	return
end

local api = vim.api
local cmd = vim.cmd

local vim_version = vim.version()
if vim_version.minor < 12 then
	return
end

vim.opt.shortmess:append("I")

cmd("highlight AsciiBorder guifg=#280068")
cmd("highlight Ascii guifg=#280068 guibg=#3f007f")

local NVIM_VERSION = "NVIM " .. vim_version.major .. "." .. vim_version.minor

local function pad_str(padding, str)
	local result = ""
	for _ = 1, padding do
		result = result .. " "
	end
	return result .. str
end

local ascii_coords = {
	{ 25, 28 },
	{ 38, 50 },
	{ 22, 67 },
	{ 14, 77 },
	{ 14, 57 },
	{ 11, 48 },
	{ 18, 56 },
	{ 8, 87 },
	{ 8, 79 },
	{ 18, 62 },
	{ 11, 59 },
	{ 14, 51 },
	{ 16, 81 },
	{ 18, 69 },
	{ 37, 50 },
	{ 25, 28 },
}

local intro_active = false
local intro_buf = nil

local function color_buf(buf, padding)
	local ns = api.nvim_create_namespace("ascii_ns")

	for line, coord in ipairs(ascii_coords) do
		api.nvim_buf_add_highlight(buf, ns, "AsciiBorder", line, 0, coord[1] + padding)
		api.nvim_buf_add_highlight(buf, ns, "Ascii", line, coord[1] + padding, coord[2] + padding - 1)
		api.nvim_buf_add_highlight(buf, ns, "AsciiBorder", line, coord[2] + padding - 1, 1000)
	end
end

local function dismiss_intro()
	if not intro_active then
		return
	end
	intro_active = false

	local win = api.nvim_get_current_win()

	if intro_buf and api.nvim_buf_is_valid(intro_buf) then
		api.nvim_buf_delete(intro_buf, { force = true })
	end
	intro_buf = nil

	vim.cmd("enew")

	api.nvim_win_set_option(win, "colorcolumn", "100")
	api.nvim_win_set_option(win, "relativenumber", true)
	api.nvim_win_set_option(win, "number", true)
	api.nvim_win_set_option(win, "list", true)
end

local function set_ascii_bg()
	if not intro_active then
		return
	end

	local height = api.nvim_get_option("lines")
	local width = api.nvim_get_option("columns")

	local ascii = {
		"                                              ",
		"                   ▁▁▁▁▁▁▁",
		"             ▁▁▄▄▟█████████▙▄▄▁▁",
		"            ▟███████████████████▙",
		"          ▄████▛▀▀▀▀▀▀▀▀▀▀▀▀▀▜████▄",
		"         ▟████▛               ▜████▙",
		"        ▟████▛                 ▜████▙",
		"       ▐████▛                   ▜████▌",
		"       ████▛                     ▜████",
		"       ████▙                     ▟████",
		"       ▐████▙                   ▟████▌",
		"        ▜████▙                 ▟████▛",
		"         ▜████▙               ▟████▛",
		"          ▀████▙▄▄▄▄▄▄▄▄▄▄▄▄▄▟████▀",
		"            ▜███████████████████▛",
		"             ▔▔▀▀▜█████████▛▀▀▔▔",
		"                   ▔▔▔▔▔▔▔",
		"__NVIM_VERSION__",
		"",
		" Nvim is open source and freely distributable",
		"            https://neovim.io/#chat",
		"",
		" [f] Find Files     [g] Grep",
		" [r] Recent Files  [c] Config",
		" [o] Old Session  [h] Help",
		" [q] Quit",
		"",
		"type  :help nvim<Enter>       if you are new",
		"type  :q<Enter>               to exit",
	}

	local ascii_rows = #ascii
	local ascii_cols = #ascii[1]
	local pad_cols = math.floor((width - ascii_cols) / 2)

	if height < ascii_rows or width < ascii_cols then
		return
	end

	for i, _ in ipairs(ascii) do
		if ascii[i] == "__NVIM_VERSION__" then
			ascii[i] = pad_str(pad_cols, pad_str(math.ceil((ascii_cols - #NVIM_VERSION) / 2), NVIM_VERSION))
		elseif ascii[i] ~= "" then
			ascii[i] = pad_str(pad_cols, ascii[i])
		else
			ascii[i] = pad_str(pad_cols, "")
		end
	end

	local buf = api.nvim_get_current_buf()
	local win = api.nvim_get_current_win()

	intro_buf = buf

	api.nvim_buf_set_lines(buf, 0, -1, false, ascii)
	color_buf(buf, pad_cols)

	api.nvim_buf_set_option(buf, "modified", false)
	api.nvim_buf_set_option(buf, "buflisted", false)
	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "buftype", "nofile")
	api.nvim_buf_set_option(buf, "swapfile", false)
	api.nvim_win_set_option(win, "colorcolumn", "")
	api.nvim_win_set_option(win, "relativenumber", false)
	api.nvim_win_set_option(win, "number", false)
	api.nvim_win_set_option(win, "list", false)

	vim.keymap.set("n", "f", function()
		dismiss_intro()
		require("fff").find_files()
	end, { buffer = buf })

	vim.keymap.set("n", "g", function()
		dismiss_intro()
		require("fff").live_grep()
	end, { buffer = buf })

	vim.keymap.set("n", "r", function()
		dismiss_intro()
		Snacks.picker.oldfiles()
	end, { buffer = buf })

	vim.keymap.set("n", "c", function()
		dismiss_intro()
		vim.cmd("edit ~/.config/nvim/init.lua")
	end, { buffer = buf })

	vim.keymap.set("n", "o", function()
		dismiss_intro()
		require("persistence").load({ last = true })
	end, { buffer = buf })

	vim.keymap.set("n", "h", function()
		dismiss_intro()
		vim.cmd("help")
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		dismiss_intro()
		vim.cmd("qa")
	end, { buffer = buf })
end

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		intro_active = true
		set_ascii_bg()

		vim.api.nvim_create_autocmd("VimResized", {
			callback = function()
				if intro_active then
					set_ascii_bg()
				end
			end,
		})
	end,
})
