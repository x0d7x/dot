return {
	"neovim/nvim-lspconfig",
	dependencies = {
		-- Automatically install LSPs and related tools to stdpath for Neovim
		{ "mason-org/mason.nvim", config = true }, -- NOTE: Must be loaded before dependants
		-- mason-lspconfig:
		-- - Bridges the gap between LSP config names (e.g. "lua_ls") and actual Mason package names (e.g. "lua-language-server").
		-- - Used here only to allow specifying language servers by their LSP name (like "lua_ls") in `ensure_installed`.
		-- - It does not auto-configure servers — we use vim.lsp.config() + vim.lsp.enable() explicitly for full control.
		"mason-org/mason-lspconfig.nvim",
		-- mason-tool-installer:
		-- - Installs LSPs, linters, formatters, etc. by their Mason package name.
		-- - We use it to ensure all desired tools are present.
		-- - The `ensure_installed` list works with mason-lspconfig to resolve LSP names like "lua_ls".
		"WhoIsSethDaniel/mason-tool-installer.nvim",

		-- Useful status updates for LSP.
		{
			"j-hui/fidget.nvim",
			opts = {
				notification = {
					window = {
						winblend = 0, -- Background color opacity in the notification window
					},
				},
			},
		},

		-- Allows extra capabilities provided by nvim-cmp
		"hrsh7th/cmp-nvim-lsp",
	},
	config = function()
		-- LSP servers and clients are able to communicate to each other what features they support.
		-- By default, Neovim doesn't support everything that is in the LSP specification.
		-- When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
		-- So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

		-- Enable the following language servers
		--
		-- Add any additional override configuration in the following tables. Available keys are:
		-- - cmd (table): Override the default command used to start the server
		-- - filetypes (table): Override the default list of associated filetypes for the server
		-- - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
		-- - settings (table): Override the default settings passed when initializing the server.
		local servers = {
			ts_ls = {},
			gopls = {},
			astro = {},
			ruff = {},
			html = { filetypes = { "html", "twig", "hbs" } },
			cssls = {},
			tailwindcss = {},
			dockerls = {},
			sqlls = {},
			terraformls = {},
			jsonls = {},
			yamlls = {},
			lua_ls = {
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
						},
						runtime = { version = "LuaJIT" },
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
						diagnostics = {
							globals = { "vim" },
							disable = { "missing-fields" },
						},
						format = {
							enable = false,
						},
					},
				},
			},
		}

		-- Ensure the servers and tools above are installed
		local ensure_installed = vim.tbl_keys(servers or {})
		vim.list_extend(ensure_installed, {
			"stylua", -- Used to format Lua code
		})
		require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

		for server, cfg in pairs(servers) do
			-- For each LSP server (cfg), we merge:
			-- 1. A fresh empty table (to avoid mutating capabilities globally)
			-- 2. Your capabilities object with Neovim + cmp features
			-- 3. Any server-specific cfg.capabilities if defined in `servers`
			cfg.capabilities = vim.tbl_deep_extend("force", {}, capabilities, cfg.capabilities or {})

			vim.lsp.config(server, cfg)
			vim.lsp.enable(server)
		end
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
				prefix = "●",
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
		-- check the lsp
		local function lsp_status_short()
			local bufnr = vim.api.nvim_get_current_buf()
			local clients = vim.lsp.get_clients({ bufnr = bufnr })

			if #clients == 0 then
				return "" -- Return empty string when no LSP
			end

			local names = {}
			for _, client in ipairs(clients) do
				table.insert(names, client.name)
			end

			return "󰒋 " .. table.concat(names, ",")
		end
		local function formatter_status()
			local ok, conform = pcall(require, "conform")
			if not ok then
				return ""
			end

			local formatters = conform.list_formatters_to_run(0)
			if #formatters == 0 then
				return ""
			end

			local formatter_names = {}
			for _, formatter in ipairs(formatters) do
				table.insert(formatter_names, formatter.name)
			end

			return "󰉿 " .. table.concat(formatter_names, ",")
		end

		local function linter_status()
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
		-- Safe wrapper functions for statusline
		local function safe_lsp_status()
			local ok, result = pcall(lsp_status_short)
			return ok and result or ""
		end

		local function safe_formatter_status()
			local ok, result = pcall(formatter_status)
			return ok and result or ""
		end

		local function safe_linter_status()
			local ok, result = pcall(linter_status)
			return ok and result or ""
		end

		_G.lsp_status = safe_lsp_status
		_G.formatter_status = safe_formatter_status
		_G.linter_status = safe_linter_status

		-- THEN set the statusline
		vim.opt.statusline = table.concat({
			-- "%{v:lua.git_branch()}",       -- Git branch
			"%f", -- File name
			"%m", -- Modified flag
			"%r", -- Readonly flag
			"%=", -- Right align
			"%{v:lua.linter_status()}", -- Linter status
			"%{v:lua.formatter_status()}", -- Formatter status
			"%{v:lua.lsp_status()}", -- LSP status
			" %l:%c", -- Line:Column
			" %p%%", -- Percentage through file
		}, " ")
	end,
}
