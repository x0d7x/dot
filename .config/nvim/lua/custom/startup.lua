if vim.fn.argc() > 0 then
	return
end

local api = vim.api
local cmd = vim.cmd
local start_time = vim.g.start_time or vim.loop.hrtime()

local vim_version = vim.version()
if vim_version.minor < 12 then
	return
end

vim.opt.shortmess:append("I")

local NVIM_VERSION = "NVIM " .. vim_version.major .. "." .. vim_version.minor

local function center_str(str, width)
	local len = #str
	if len >= width then
		return str
	end
	local left = math.floor((width - len) / 2)
	local right = width - len - left
	return string.rep(" ", left) .. str .. string.rep(" ", right)
end

local function pad_str(padding, str)
	local result = ""
	for _ = 1, padding do
		result = result .. " "
	end
	return result .. str
end

local function format_shortcut(left, right)
	local left_width = 18
	local right_width = 10
	local gap = 2
	local line = string.format("%-" .. left_width .. "s", left)
	line = line .. string.rep(" ", gap)
	if right and right ~= "" then
		line = line .. string.format("%-" .. right_width .. "s", right)
	else
		line = line .. string.rep(" ", right_width)
	end
	return line
end

local intro_active = false
local intro_buf = nil
local cached_stats = nil

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

	api.nvim_win_set_option(win, "colorcolumn", "100")
	api.nvim_win_set_option(win, "relativenumber", true)
	api.nvim_win_set_option(win, "number", true)
	api.nvim_win_set_option(win, "list", true)
end

local function get_stats()
	if cached_stats then
		return cached_stats
	end

	local ok, lazy = pcall(require, "lazy")
	if not ok then
		return "⚡ Loading..."
	end

	local stats = lazy.stats()
	if not stats or stats.loaded == 0 then
		return "⚡ Loading..."
	end

	local startup_ms = stats.startuptime
	if not startup_ms or startup_ms == 0 then
		startup_ms = math.floor((vim.loop.hrtime() - start_time) / 1000000)
	end

	cached_stats = "⚡ " .. stats.loaded .. " plugins in " .. math.floor(startup_ms) .. "ms"
	return cached_stats
end

local function set_ascii_bg()
	if not intro_active then
		return
	end

	local height = api.nvim_get_option("lines")
	local width = api.nvim_get_option("columns")

	local ascii = {
		[[_,    _   _    ,_]],
		[[.o888P     Y8o8Y     Y888o.]],
		[[d88888      88888      88888b]],
		[[d888888b_  _d88888b_  _d888888b]],
		[[8888888888888888888888888888888]],
		[[8888888888888888888888888888888]],
		[[YJGS8P"Y888P"Y888P"Y888P"Y8888P]],
		[[Y888   '8'   Y8P   '8'   888Y]],
		[['8o          V          o8']],
		[[`                     `]],
		"__NVIM_VERSION__",
		"__STATS__",
		"",
		" Nvim is open source and freely distributable",
		"            https://neovim.io/#chat",
		"",
		"__SHORTCUT_1__",
		"__SHORTCUT_2__",
		"__SHORTCUT_3__",
		"__SHORTCUT_4__",
		"",
	}

	local ascii_rows = #ascii
	local ascii_cols = #ascii[1]
	local pad_cols = math.floor((width - ascii_cols) / 2)
	if height < ascii_rows or width < ascii_cols then
		return
	end
	local pad_rows = math.floor((height - ascii_rows) / 2)

	for i, _ in ipairs(ascii) do
		if ascii[i] == "__NVIM_VERSION__" then
			ascii[i] = center_str(NVIM_VERSION, width)
		elseif ascii[i] == "__STATS__" then
			ascii[i] = center_str(get_stats(), width)
		elseif ascii[i] == "__SHORTCUT_1__" then
			ascii[i] = center_str(format_shortcut("[f] Find Files", "[g] Grep"), width)
		elseif ascii[i] == "__SHORTCUT_2__" then
			ascii[i] = center_str(format_shortcut("[r] Recent Files", "[c] Config"), width)
		elseif ascii[i] == "__SHORTCUT_3__" then
			ascii[i] = center_str(format_shortcut("[o] Old Session", "[h] Help"), width)
		elseif ascii[i] == "__SHORTCUT_4__" then
			ascii[i] = center_str(format_shortcut("[q] Quit", nil), width)
		elseif ascii[i] ~= "" then
			ascii[i] = center_str(ascii[i], width)
		else
			ascii[i] = pad_str(pad_cols, "")
		end
	end

	if pad_rows > 0 then
		local padded = {}
		for _ = 1, pad_rows do
			table.insert(padded, "")
		end
		for _, line in ipairs(ascii) do
			table.insert(padded, line)
		end
		ascii = padded
	end

	local buf = api.nvim_get_current_buf()
	local win = api.nvim_get_current_win()

	intro_buf = buf

	api.nvim_buf_set_lines(buf, 0, -1, false, ascii)
	vim.cmd("redraw")

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
		require("fff").find_files({
			layout = {
				fullscreen = false,
			},
		})
	end, { buffer = buf })

	vim.keymap.set("n", "g", function()
		require("fff").live_grep({
			layout = {
				fullscreen = false,
			},
		})
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

local function is_intro_only()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.bo[buf].buftype

		if bt ~= "" and bt ~= "nofile" then
			return false
		end
	end
	return true
end

local function is_real_buffer(buf)
	if not api.nvim_buf_is_valid(buf) then
		return false
	end
	if vim.bo[buf].buftype ~= "" then
		return false
	end
	local name = api.nvim_buf_get_name(buf)
	if name == "" then
		return false
	end
	return true
end

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		intro_active = true
		set_ascii_bg()

		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function(ev)
				if intro_active and is_real_buffer(ev.buf) then
					dismiss_intro()
				end
			end,
		})

		vim.api.nvim_create_autocmd("VimResized", {
			callback = function()
				if intro_active and is_intro_only() then
					set_ascii_bg()
				end
			end,
		})
	end,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "LazyDone",
	callback = function()
		if intro_active then
			vim.defer_fn(function()
				if intro_active then
					local ok, err = pcall(set_ascii_bg)
					if not ok then
						vim.notify("Intro error: " .. err, vim.log.levels.ERROR)
					end
				end
			end, 100)
		end
	end,
})
