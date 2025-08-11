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
	desc = "Notify when recording starts and stops",
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
