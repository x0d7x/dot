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
require("config.autocmds")
require("config.statusline")
require("custom.startup")
vim.cmd(":hi statusline guibg=NONE")
