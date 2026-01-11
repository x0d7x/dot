return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	opts = {
		formatters_by_ft = {
			go = { "goimports", "gofmt" },
			nix = { "nixfmt" },
			lua = { "stylua" },
			javascript = { "prettier" },
			typescript = { "prettier" },
			javascriptreact = { "prettier" },
			typescriptreact = { "prettier" },
			json = { "prettier" },
			astro = { "prettier" },
			jsonc = { "prettier" },
			yaml = { "prettier" },
			markdown = { "prettier" },
			html = { "prettier" },
			css = { "prettier" },
			scss = { "prettier" },
			python = { "isort", "black" },
			php = { "pint" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			rust = { "rustfmt" },
		},
		default_format_opts = {
			lsp_fallback = true,
		},
		format_on_save = {
			timeout_ms = 1000,
			lsp_fallback = true,
		},
	},
	init = function()
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
