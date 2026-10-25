vim.g.mapleader = " "
vim.g.maplocalleader = " "
require("custom.startup")
require("core.pack")
require("config.utils")
require("core.lsp")
-- require("custom.colorscheme")
require("core.Mason-path")
require("config.mason-verify")
require("config.keymaps")
require("custom.oil")
require("custom.finder")
require("config.opts")
require("config.autocmds")
require("vim._core.ui2").enable({
	enable = true,
	msg = {
		target = "cmd",
		timeout = 4500,
		pager = { height = 0.5 },
		dialog = { height = 0.5 },
		cmd = { maxheight = 0.5 },
		msg = { height = 0.5 },
	},
})
require("config.statusline")
require("custom.jump")
require("custom.marks")
vim.cmd(":hi statusline guibg=NONE")

local matugen_path = vim.fn.expand("~/.config/nvim/matugen.vim")

local transparent_groups = {
	"Normal",
	"NormalNC",
	"SignColumn",
	"EndOfBuffer",
	"MsgArea",
	"NormalFloat",
	"FloatBorder",
	"Pmenu",
	"PmenuSbar",
	"PmenuThumb",
	"StatusLine",
	"StatusLineNC",
	"TabLine",
	"TabLineFill",
	"WinBar",
	"WinBarNC",
	"FoldColumn",
	"LineNr",
	"CursorLineNr",
}

local function apply_transparency()
	for _, group in ipairs(transparent_groups) do
		vim.api.nvim_set_hl(0, group, {
			bg = "NONE",
			ctermbg = "NONE",
		})
	end
end

local function load_matugen()
	if vim.fn.filereadable(matugen_path) == 1 then
		vim.cmd("source " .. vim.fn.fnameescape(matugen_path))
	end

	-- Apply transparency after the colors are loaded.
	apply_transparency()

	-- Keep comments italic.
	vim.api.nvim_set_hl(0, "Comment", { italic = true })
end

vim.api.nvim_create_autocmd("Signal", {
	pattern = "SIGUSR1",
	callback = load_matugen,
})

-- Load the generated palette on startup.
load_matugen()
