local capabilities = require("blink.cmp").get_lsp_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, {
	workspace = {
		fileOperations = {
			didRename = true,
			willRename = true,
		},
	},
})

local ft_to_lsp = {
	lua = "lua_ls",
	go = "gopls",
	typescript = "ts_ls",
	typescriptreact = "ts_ls",
	javascript = "ts_ls",
	javascriptreact = "ts_ls",
	astro = "astro",
	html = "html",
	css = "cssls",
	tailwindcss = "tailwindcss",
	-- vue = "vue_ls",
}

for _, lsp in pairs(ft_to_lsp) do
	local ok, config = pcall(require, "lsp." .. lsp)
	if ok then
		config.capabilities = capabilities
		vim.lsp.config(lsp, config)
	end
end

local function enable_lsp_for_current_buffer()
	local ft = vim.bo.filetype
	local lsp = ft_to_lsp[ft]

	if not lsp then
		vim.notify("❌ No LSP for filetype: " .. ft, vim.log.levels.WARN)
		return
	end

	vim.lsp.enable({ lsp })
	vim.notify("✅ LSP enabled for " .. ft .. " using " .. lsp)
end

vim.keymap.set("n", "<leader>tl", enable_lsp_for_current_buffer, { desc = "Enable LSP for buffer" })

local diagnostics = {
	float = {
		border = "rounded",
		source = true,
	},
	underline = true,
	update_in_insert = false,
	virtual_text = {
		current_line = true,
		spacing = 4,
		source = "if_many",
		prefix = "",
	},
	virtual_lines = false,
	severity_sort = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			[vim.diagnostic.severity.WARN] = "WarningMsg",
		},
	},
}

vim.diagnostic.config(vim.deepcopy(diagnostics))

-- helper fun from https://github.com/adibhanna/nvim/blob/main/lua/core/lsp.lua

local function restart_lsp(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	for _, client in ipairs(clients) do
		vim.lsp.stop_client(client.id)
	end

	vim.defer_fn(function()
		vim.cmd("edit")
	end, 100)
end

vim.api.nvim_create_user_command("LspRestart", function()
	restart_lsp()
end, {})

local function lsp_status()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #clients == 0 then
		print("󰅚 No LSP clients attached")
		return
	end

	print("󰒋 LSP Status for buffer " .. bufnr .. ":")
	print("─────────────────────────────────")

	for i, client in ipairs(clients) do
		print(string.format("󰌘 Client %d: %s (ID: %d)", i, client.name, client.id))
		print("  Root: " .. (client.config.root_dir or "N/A"))
		print("  Filetypes: " .. table.concat(client.config.filetypes or {}, ", "))

		-- Check capabilities
		local caps = client.server_capabilities
		local features = {}
		if caps.completionProvider then
			table.insert(features, "completion")
		end
		if caps.hoverProvider then
			table.insert(features, "hover")
		end
		if caps.definitionProvider then
			table.insert(features, "definition")
		end
		if caps.referencesProvider then
			table.insert(features, "references")
		end
		if caps.renameProvider then
			table.insert(features, "rename")
		end
		if caps.codeActionProvider then
			table.insert(features, "code_action")
		end
		if caps.documentFormattingProvider then
			table.insert(features, "formatting")
		end

		print("  Features: " .. table.concat(features, ", "))
		print("")
	end
end

vim.api.nvim_create_user_command("LspStatus", lsp_status, { desc = "Show detailed LSP status" })

local function check_lsp_capabilities()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #clients == 0 then
		print("No LSP clients attached")
		return
	end

	for _, client in ipairs(clients) do
		print("Capabilities for " .. (client.name or "<unknown>") .. ":")

		-- ‼ safer: fall back to empty table
		local caps = client.server_capabilities or {}

		local capability_list = {
			{ "Completion", caps.completionProvider },
			{ "Hover", caps.hoverProvider },
			{ "Signature Help", caps.signatureHelpProvider },
			{ "Go to Definition", caps.definitionProvider },
			{ "Go to Declaration", caps.declarationProvider },
			{ "Go to Implementation", caps.implementationProvider },
			{ "Go to Type Definition", caps.typeDefinitionProvider },
			{ "Find References", caps.referencesProvider },
			{ "Document Highlight", caps.documentHighlightProvider },
			{ "Document Symbol", caps.documentSymbolProvider },
			{ "Workspace Symbol", caps.workspaceSymbolProvider },
			{ "Code Action", caps.codeActionProvider },
			{ "Code Lens", caps.codeLensProvider },
			{ "Document Formatting", caps.documentFormattingProvider },
			{ "Document Range Formatting", caps.documentRangeFormattingProvider },
			{ "Rename", caps.renameProvider },
			{ "Folding Range", caps.foldingRangeProvider },
			{ "Selection Range", caps.selectionRangeProvider },
		}

		for _, cap in ipairs(capability_list) do
			local status = (cap[2] ~= nil and cap[2] ~= false) and "✓" or "✗"
			print(string.format("  %s %s", status, cap[1]))
		end
		print("")
	end
end

vim.api.nvim_create_user_command("LspCapabilities", check_lsp_capabilities, { desc = "Show LSP capabilities" })

local function lsp_diagnostics_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)

	local counts = { ERROR = 0, WARN = 0, INFO = 0, HINT = 0 }

	for _, diagnostic in ipairs(diagnostics) do
		local severity = vim.diagnostic.severity[diagnostic.severity]
		counts[severity] = counts[severity] + 1
	end

	print("󰒡 Diagnostics for current buffer:")
	print("  Errors: " .. counts.ERROR)
	print("  Warnings: " .. counts.WARN)
	print("  Info: " .. counts.INFO)
	print("  Hints: " .. counts.HINT)
	print("  Total: " .. #diagnostics)
end

vim.api.nvim_create_user_command("LspDiagnostics", lsp_diagnostics_info, { desc = "Show LSP diagnostics count" })

local function lsp_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	print("═══════════════════════════════════")
	print("           LSP INFORMATION          ")
	print("═══════════════════════════════════\n")

	print("󰈙 Log file:        " .. vim.lsp.get_log_path())
	print("󰈔 Filetype:        " .. vim.bo.filetype)
	print("󰈮 Buffer:          " .. bufnr)
	print("󰈔 CWD:             " .. (vim.fn.getcwd() or "N/A") .. "\n")

	if #clients == 0 then
		print("󰅚 No LSP clients attached to buffer " .. bufnr .. "\n")
		print("Possible reasons:")
		print("  • No language server installed for " .. vim.bo.filetype)
		print("  • Language server not configured")
		print("  • Not in a project root directory")
		print("  • File type not recognized")
		return
	end

	print("󰒋 Clients attached (" .. #clients .. "):")
	print("─────────────────────────────────")

	for i, client in ipairs(clients) do
		print(string.format("󰌘 Client %d: %s", i, client.name or "<unknown>"))
		print("  ID:          " .. client.id)
		print("  Root dir:    " .. (client.config.root_dir or "Not set"))
		print("  Command:     " .. table.concat(client.config.cmd or {}, " "))
		print("  Filetypes:   " .. table.concat(client.config.filetypes or {}, ", "))

		-- status
		print("  Status:      " .. (client.is_stopped and client:is_stopped() and "󰅚 Stopped" or "󰄬 Running"))

		-- workspace folders
		local folders = client.workspace_folders or {}
		if #folders > 0 then
			print("  Workspace folders:")
			for _, folder in ipairs(folders) do
				print("    • " .. folder.name)
			end
		end

		-- attached buffers
		local bufcount = 0
		for _ in pairs(client.attached_buffers or {}) do
			bufcount = bufcount + 1
		end
		print("  Attached buffers: " .. bufcount)

		-- key capabilities (nil-safe)
		local caps = client.server_capabilities or {}
		local key_feats = {}
		if caps.completionProvider then
			table.insert(key_feats, "completion")
		end
		if caps.hoverProvider then
			table.insert(key_feats, "hover")
		end
		if caps.definitionProvider then
			table.insert(key_feats, "definition")
		end
		if caps.documentFormattingProvider then
			table.insert(key_feats, "formatting")
		end
		if caps.codeActionProvider then
			table.insert(key_feats, "code_action")
		end

		if #key_feats > 0 then
			print("  Key features: " .. table.concat(key_feats, ", "))
		end
		print("")
	end

	-- Diagnostics summary
	local diagnostics = vim.diagnostic.get(bufnr)
	if #diagnostics > 0 then
		print("󰒡 Diagnostics Summary:")
		local counts = { ERROR = 0, WARN = 0, INFO = 0, HINT = 0 }

		for _, diagnostic in ipairs(diagnostics) do
			local severity = vim.diagnostic.severity[diagnostic.severity]
			counts[severity] = counts[severity] + 1
		end

		print("  󰅚 Errors: " .. counts.ERROR)
		print("  󰀪 Warnings: " .. counts.WARN)
		print("  󰋽 Info: " .. counts.INFO)
		print("  󰌶 Hints: " .. counts.HINT)
		print("  Total: " .. #diagnostics)
	else
		print("󰄬 No diagnostics")
	end

	print("")
	print("Use :LspLog to view detailed logs")
	print("Use :LspCapabilities for full capability list")
end

-- Create command
vim.api.nvim_create_user_command("LspInfo", lsp_info, { desc = "Show comprehensive LSP information" })

--blend LspProgrrss
do
	local blend = blend._282828;

	(function(config)
		local function setup_highlights()
			local opt = { underline = true, bold = true }
			vim.api.nvim_set_hl(0, "LspProgressSpinner", vim.tbl_extend("force", { fg = config.colors.spinner }, opt))
			vim.api.nvim_set_hl(0, "LspProgressTitle", vim.tbl_extend("force", { fg = config.colors.title }, opt))
			vim.api.nvim_set_hl(
				0,
				"LspProgressMessage",
				vim.tbl_extend("force", { fg = config.colors.progress, italic = true }, opt)
			)
			vim.api.nvim_set_hl(
				0,
				"LspProgressPercentage",
				vim.tbl_extend("force", { fg = config.colors.percentage }, opt)
			)
		end

		setup_highlights()

		local ns_id = vim.api.nvim_create_namespace(config.namespace_name)
		local extmark_id
		local progress_data = {}
		local spinner_index = 1
		local spinner_timer
		local hide_timer

		local function get_spinner()
			local frame = config.spinner_frames[spinner_index]
			spinner_index = (spinner_index % #config.spinner_frames) + 1
			return frame
		end

		local function create_virt_text(data)
			local virt_text = {}
			local spinner = get_spinner()

			table.insert(virt_text, { spinner .. " ", "LspProgressSpinner" })

			if config.show_title and data.title then
				table.insert(virt_text, { data.title, "LspProgressTitle" })
				if data.message or data.percentage then
					table.insert(virt_text, { " ", "Normal" })
				end
			end

			if config.show_message and data.message then
				table.insert(virt_text, { data.message, "LspProgressMessage" })
				if data.percentage then
					table.insert(virt_text, { " ", "Normal" })
				end
			end

			if config.show_percentage and data.percentage then
				table.insert(virt_text, { string.format("(%d%%)", data.percentage), "LspProgressPercentage" })
			end

			return virt_text
		end

		local function update_extmark(data)
			if not data then
				return
			end

			local bufnr = vim.api.nvim_get_current_buf()
			local cursor_pos = vim.api.nvim_win_get_cursor(0)
			local row = cursor_pos[1] - 1
			local virt_text = create_virt_text(data)

			if extmark_id then
				pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
			end

			extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
				virt_text = virt_text,
				virt_text_pos = "eol",
				priority = 1000,
			})
		end

		local function clear_extmark()
			if extmark_id then
				local bufnr = vim.api.nvim_get_current_buf()
				pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
				extmark_id = nil
			end
		end

		local function has_active_progress()
			for _, data in pairs(progress_data) do
				if data.active then
					return true
				end
			end
			return false
		end

		local function get_combined_progress()
			local active_items = {}
			for _, data in pairs(progress_data) do
				if data.active then
					table.insert(active_items, data)
				end
			end

			if #active_items == 0 then
				return nil
			end

			table.sort(active_items, function(a, b)
				return (a.percentage or 0) > (b.percentage or 0)
			end)

			return active_items[1]
		end

		local function start_spinner()
			if spinner_timer then
				return
			end

			spinner_timer = vim.uv.new_timer()
			spinner_timer:start(
				0,
				config.update_interval,
				vim.schedule_wrap(function()
					local data = get_combined_progress()
					if data then
						update_extmark(data)
					else
						if spinner_timer then
							spinner_timer:stop()
							spinner_timer:close()
							spinner_timer = nil
						end
					end
				end)
			)
		end

		local function schedule_hide()
			if hide_timer then
				hide_timer:stop()
				hide_timer:close()
			end

			hide_timer = vim.uv.new_timer()
			hide_timer:start(
				config.auto_hide_delay,
				0,
				vim.schedule_wrap(function()
					clear_extmark()
					if hide_timer then
						hide_timer:close()
						hide_timer = nil
					end
				end)
			)
		end

		local function handle_progress(args)
			local client_id = args.data.client_id
			local params = args.data.params
			local token = params.token
			local value = params.value

			if not token then
				return
			end

			local key = string.format("%d:%s", client_id, tostring(token))

			if value.kind == "begin" then
				progress_data[key] = {
					percentage = value.percentage,
					title = value.title,
					message = value.message,
					active = true,
				}
				start_spinner()
			elseif value.kind == "report" then
				if progress_data[key] then
					progress_data[key].message = value.message or progress_data[key].message
					progress_data[key].percentage = value.percentage or progress_data[key].percentage
				end
			elseif value.kind == "end" then
				if progress_data[key] then
					progress_data[key].active = false
					progress_data[key] = nil
				end

				if not has_active_progress() then
					schedule_hide()
				end
			end
		end

		vim.api.nvim_create_augroup("LspProgressExtmark", { clear = true })
		vim.api.nvim_create_autocmd("LspProgress", {
			group = "LspProgressExtmark",
			callback = handle_progress,
		})
	end)({
		namespace_name = "lsp_progress_extmark",
		show_percentage = true,
		show_title = true,
		show_message = true,
		colors = {
			spinner = blend("#ff6b47", 55),
			title = blend("#ffb347", 25),
			progress = blend("#b3c6a7", 25),
			percentage = blend("#87ceeb", 55),
		},
		-- spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
		-- spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
		spinner_frames = { "◐", "◓", "◑", "◒" },
		-- spinner_frames = { "◰", "◳", "◲", "◱" },
		-- spinner_frames = { "▱", "▰", "▰▱", "▰▰" },
		-- spinner_frames = { "○", "⬭", "●", "⬮" },
		-- spinner_frames = { "○   ", " ○  ", "  ○ ", "   ○", "  ○ ", " ○  " },
		-- spinner_frames = {
		-- 	"○○○",
		-- 	"●○○",
		-- 	"○●○",
		-- 	"○○●",
		-- 	"●●○",
		-- 	"●○●",
		-- 	"○●●",
		-- 	"●●●",
		-- },
		-- spinner_frames = { "⬢", "⬡", "⬢", "⬡" },
		-- spinner_frames = { "◐", "◓", "◑", "◒" },
		auto_hide_delay = 10,
		update_interval = 100,
	})
end
-- spinners
