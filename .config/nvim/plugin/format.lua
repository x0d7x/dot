local pack = require("core.pack")

pack.add({
	"https://github.com/stevearc/conform.nvim",
	"https://github.com/mfussenegger/nvim-lint",
})

require("conform").setup({
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
		-- kdl = { "kdlfmt" },
	},
	-- formatters = {
	-- 	kdlfmt = {
	-- 		command = "kdlfmt",
	-- 		args = { "format" },
	-- 	},
	-- },
	default_format_opts = {
		lsp_fallback = true,
	},
	format_on_save = {
		timeout_ms = 1000,
		lsp_fallback = true,
	},
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

local lint = require("lint")
local golangcilint = require("lint").linters.golangcilint
golangcilint.ignore_exitcode = true

lint.linters_by_ft = {
	javascript = { "eslint_d" },
	typescript = { "eslint_d" },
	javascriptreact = { "eslint_d" },
	typescriptreact = { "eslint_d" },
	astro = { "eslint_d" },
	go = { "golangcilint" },
	html = {},
	css = {},
	tailwindcss = {},
	dockerfile = {},
}

lint.linters.eslint_d = {
	cmd = "eslint_d",
	stdin = true,
	args = {
		"--format",
		"json",
		"--stdin",
		"--stdin-filename",
		function()
			return vim.api.nvim_buf_get_name(0)
		end,
	},
	stream = "stdout",
	ignore_exitcode = true,
	parser = require("lint.parser").from_errorformat("%f:%l:%c: %m", {
		source = "eslint_d",
		format = "json",
	}),
}

local function debounce(ms, fn)
	local timer = vim.uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end

local function do_lint()
	local names = lint._resolve_linter_by_ft(vim.bo.filetype)
	names = vim.list_extend({}, names)
	vim.list_extend(names, lint.linters_by_ft._ or {})
	vim.list_extend(names, lint.linters_by_ft["*"] or {})

	local ctx = { filename = vim.api.nvim_buf_get_name(0) }
	ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")

	names = vim.tbl_filter(function(name)
		local linter = lint.linters[name]
		if not linter then
			vim.notify("Linter not found: " .. name, vim.log.levels.WARN, { title = "nvim-lint" })
		end
		return linter and not (linter.condition and not linter.condition(ctx))
	end, names)

	if #names > 0 then
		lint.try_lint(names)
	end
end

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufReadPost" }, {
	group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
	callback = debounce(100, do_lint),
})
