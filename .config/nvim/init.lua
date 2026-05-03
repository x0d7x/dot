vim.g.mapleader = " "
vim.g.maplocalleader = " "
require("core.pack")
require("config.utils")
require("core.lsp")
-- require("custom.colorscheme")
require("core.Mason-path")
require("config.mason-verify")
require("config.keymaps")
require("config.opts")
require("vim._core.ui2").enable({
	enable = true,
	msg = {
		target = "cmd",
		pager = { height = 0.5 },
		dialog = { height = 0.5 },
		cmd = { height = 0.5 },
		msg = { height = 0.5, timeout = 4500 },
	},
})
require("config.autocmds")
require("config.statusline")
require("custom.startup")
vim.cmd(":hi statusline guibg=NONE")
