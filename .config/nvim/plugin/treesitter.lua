local pack = require("core.pack")

pack.add({
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

local ensure_installed = {
	"bash",
	"c",
	"html",
	"javascript",
	"json",
	"toml",
	"lua",
	"luadoc",
	"luap",
	"markdown",
	"markdown_inline",
	"python",
	"regex",
	"tsx",
	"typescript",
	"vue",
	"vim",
	"vimdoc",
	"yaml",
	"rust",
	"go",
	"gomod",
	"gowork",
	"gosum",
	"php",
	"astro",
}

-- Install parsers on buffer enter
vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function(args)
		if not args.filetype or args.filetype == "" then
			return
		end

		local lang = vim.treesitter.language.get_lang(args.filetype)
		if not lang then
			return
		end

		local ts = require("nvim-treesitter")
		ts.install(lang)
		vim.defer_fn(function()
			vim.treesitter.start()
		end, 100)
		vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

		local win = vim.fn.bufwinid(args.buf)
		if win > 0 then
			vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
			vim.wo[win].foldmethod = "expr"
		end
	end,
})

-- Install ensure_installed parsers on startup
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		local ts = require("nvim-treesitter")
		ts.install(ensure_installed)
	end,
})
