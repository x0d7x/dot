local pack = require("core.pack")

pack.add({
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

local ensure_installed = {
	"bash",
	"html",
	"javascript",
	"json",
	"toml",
	"luadoc",
	"luap",
	"markdown_inline",
	"python",
	"regex",
	"tsx",
	"typescript",
	"vue",
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
local installed = {}

vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function(args)
		local buf = args.buf
		local ft = vim.bo[buf].filetype

		local lang = vim.treesitter.language.get_lang(ft)
		if not lang then
			return
		end

		local ok_add = pcall(vim.treesitter.language.add, lang)
		if not ok_add then
			return
		end

		pcall(vim.treesitter.start, buf, lang)
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
