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
local installed = {}

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local buf = args.buf

		if vim.bo[buf].buftype ~= "" then
			return
		end

		local ft = vim.bo[buf].filetype
		if not ft or ft == "" then
			return
		end

		local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
		if not ok or not lang then
			return
		end

		if not installed[lang] then
			installed[lang] = true
			require("nvim-treesitter").install(lang)
		end

		pcall(vim.treesitter.start, buf, lang)

		vim.bo[buf].indentexpr = "v:lua.vim.treesitter.indentexpr()"

		local win = vim.fn.bufwinid(buf)
		if win ~= -1 then
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
