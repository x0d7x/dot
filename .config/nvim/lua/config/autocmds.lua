local api = vim.api
local opt = vim.opt

local function augroup(name)
	return api.nvim_create_augroup("custom_" .. name, { clear = true })
end

-- ========== Basic Autocmds ========== --

api.nvim_create_autocmd("BufEnter", {
	desc = "Don't auto comment new lines",
	group = augroup("format_options"),
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
})

vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
	group = augroup("recording"),
	callback = function(event)
		if event.event == "RecordingEnter" then
			local reg = vim.fn.reg_recording()
			if reg ~= "" then
				vim.notify("🔴 Recording macro @" .. reg, vim.log.levels.INFO, { title = "Macro" })
			end
		elseif event.event == "RecordingLeave" then
			vim.notify("⏹️ Stopped recording macro", vim.log.levels.INFO, { title = "Macro" })
		end
	end,
	desc = "Adjust cmdheight for macro recording",
})

api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight selection on yank",
	group = augroup("highlight_on_yank"),
	callback = function()
		vim.highlight.on_yank({ timeout = 200 })
	end,
})

api.nvim_create_autocmd("BufReadPost", {
	desc = "Return cursor to last edit position",
	group = augroup("restore_cursor"),
	callback = function()
		local mark = api.nvim_buf_get_mark(0, '"')
		if mark[1] > 0 and mark[1] <= api.nvim_buf_line_count(0) then
			pcall(api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

api.nvim_create_autocmd("FileType", {
	pattern = "mail",
	desc = "Soft wrap for mail",
	group = augroup("mail_wrap"),
	callback = function()
		opt.wrap = true
		opt.linebreak = true
		opt.textwidth = 0
		opt.wrapmargin = 0
		opt.columns = 80
		opt.colorcolumn = "80"
	end,
})

api.nvim_create_autocmd("FileType", {
	pattern = {
		"help",
		"man",
		"qf",
		"lspinfo",
		"startuptime",
		"checkhealth",
		"PlenaryTestPopup",
		"spectre_panel",
		"tsplayground",
		"neotest-output",
		"neotest-summary",
		"neotest-output-panel",
	},
	desc = "Map 'q' to close certain filetypes",
	group = augroup("close_with_q"),
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
	end,
})

api.nvim_create_autocmd("VimResized", {
	desc = "Auto-resize windows when terminal is resized",
	group = augroup("resize_splits"),
	command = "wincmd =",
})

-- cursorline on active window

local function set_cursorline_for_active_window()
	for _, win in ipairs(api.nvim_list_wins()) do
		api.nvim_set_option_value("cursorline", win == api.nvim_get_current_win(), { win = win })
	end
end

local cursorline_group = api.nvim_create_augroup("CursorLineActiveOnly", { clear = true })

api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "InsertLeave" }, {
	group = cursorline_group,
	callback = set_cursorline_for_active_window,
})

api.nvim_create_autocmd({ "WinLeave", "InsertEnter" }, {
	group = cursorline_group,
	callback = set_cursorline_for_active_window,
})

api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.txt", "*.md", "*.tex" },
	desc = "Enable spell checking",
	group = augroup("enable_spell"),
	callback = function()
		opt.spell = true
		opt.spelllang = { "en" }
	end,
})

-- ========== LSP Attach Keymaps ========== --

api.nvim_create_autocmd("LspAttach", {
	group = augroup("lsp_keymaps"),
	callback = function(event)
		local buf = event.buf
		local map = function(mode, keys, func, desc)
			vim.keymap.set(mode, keys, func, { buffer = buf, desc = "LSP: " .. desc })
		end

		map("n", "gl", vim.diagnostic.open_float, "Open Diagnostic Float")
		map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
		map("n", "gs", vim.lsp.buf.signature_help, "Signature Help")
		map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
		map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
		map("n", "gr", vim.lsp.buf.references, "References")
		map("n", "gI", vim.lsp.buf.implementation, "Goto Implementation")
		map("n", "gy", vim.lsp.buf.type_definition, "Goto Type Definition")
		map("n", "<leader>lrn", vim.lsp.buf.rename, "Rename")
		map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
		map("n", "<leader>lf", function()
			vim.lsp.buf.format({ async = true })
		end, "Format File")
	end,
})

-- inline_hints
api.nvim_create_autocmd("LspAttach", {
	group = augroup("lsp_inlay_hints"),
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)

		if
			client
			and (client.server_capabilities.inlayHintProvider or client:supports_method("textDocument/inlayHint"))
		then
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		end
	end,
})

-- ========== Statusline Utilities ========== --

local function diagnostic_status()
	local icons = { Error = "", Warn = "", Info = "", Hint = "" }
	local count = { Error = 0, Warn = 0, Info = 0, Hint = 0 }

	for _, d in ipairs(vim.diagnostic.get(0)) do
		for level in pairs(count) do
			if d.severity == vim.diagnostic.severity[level:upper()] then
				count[level] = count[level] + 1
			end
		end
	end

	local parts = {}
	for level, n in pairs(count) do
		if n > 0 then
			table.insert(parts, icons[level] .. n)
		end
	end

	if #parts == 0 then
		return ""
	end
	return " " .. table.concat(parts, " ") .. " "
end

_G.DiagnosticStatus = diagnostic_status

function BufferStatus()
	local current_buf = vim.api.nvim_get_current_buf()
	local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
	local total = #listed_buffers
	local current_index = 0

	for i, buf in ipairs(listed_buffers) do
		if buf.bufnr == current_buf then
			current_index = i
			break
		end
	end

	return string.format(" [%d/%d] ", current_index, total)
end

function GitsignsStatus()
	local gs = vim.b.gitsigns_status_dict or {}
	local out = {}
	if gs.added and gs.added > 0 then
		table.insert(out, " " .. gs.added)
	end
	if gs.changed and gs.changed > 0 then
		table.insert(out, " " .. gs.changed)
	end
	if gs.removed and gs.removed > 0 then
		table.insert(out, " " .. gs.removed)
	end
	return table.concat(out, " ")
end

function Lsp_status()
	local names = {}
	for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if not client.is_stopped or not client:is_stopped() then
			table.insert(names, client.name)
		end
	end

	if #names == 0 then
		return ""
	end

	return (" [󱒄 %s]"):format(table.concat(names, ","))
end

function Formatter_status()
	local ok, conform = pcall(require, "conform")
	if not ok then
		return ""
	end
	local list = conform.list_formatters_to_run(0)
	if #list == 0 then
		return ""
	end
	return "󰉿 " .. table.concat(
		vim.tbl_map(function(f)
			return f.name
		end, list),
		","
	)
end

function Linter_status()
	local ok, lint = pcall(require, "lint")
	if not ok then
		return ""
	end
	local linters = lint.linters_by_ft[vim.bo.filetype] or {}
	if #linters == 0 then
		return ""
	end
	return "󰁨 " .. table.concat(linters, ",")
end

-- register the key to store the last key pressed
vim.on_key(function(k)
	vim.g.last_key = k
end, vim.api.nvim_create_namespace("last_key_ns"))

vim.opt.statusline = table.concat({
	"%f", -- filename
	"%m", -- modified
	-- "%y", -- filetype
	"%r", -- readonly
	"%=", -- right align
	-- "%{v:lua.GitsignsStatus()}",
	-- "%{mode()} ",  -- mode short (n,i,v)
	"%{v:lua.DiagnosticStatus()}",
	"%{exists('g:last_key') ? (' ' .. g:last_key .. ' ') : ''}",
	"%{v:lua.BufferStatus()}", -- buffer
	"%{v:lua.Lsp_status()}", -- lsp
	-- "%{v:lua.Linter_status()}",  -- linter
	-- "%{v:lua.Formatter_status()}",  -- formatter
	-- " %l:%c",  -- line and column
	-- " %p%%", -- percentage
})
