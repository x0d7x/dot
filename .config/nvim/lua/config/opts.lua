-- Set up undo directory
local o = vim.opt
local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")

-- ╭─────────────────────────────╮
-- │ General                     │
-- ╰─────────────────────────────╯
vim.g.loaded_netrw = 1 -- Disable netrw file explorer
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = " " -- Set <Leader> key to Space
vim.g.maplocalleader = " " -- Set <LocalLeader> key to Space
vim.g.snacks_animate = true
vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" }
vim.g.trouble_lualine = true

-- ╭─────────────────────────────╮
-- │ Files & Backups             │
-- ╰─────────────────────────────╯
o.undofile = true -- Enable persistent undo
o.undodir = undodir -- Set undo directory
o.undolevels = 1000 -- Max undo steps
o.undoreload = 10000 -- Lines to save for undo
o.backup = false -- Disable backup files
o.writebackup = false -- Disable write backup
o.swapfile = false -- Optional: disable swap files
o.autowrite = true -- Auto save before commands like :next, :make

-- ╭─────────────────────────────╮
-- │ Search                      │
-- ╰─────────────────────────────╯
o.ignorecase = true -- Case insensitive search...
o.smartcase = true -- ...unless capital letter in query
o.incsearch = true -- Incremental search
o.hlsearch = true -- Highlight matches
o.inccommand = "nosplit" -- Show live preview of :s command
o.grepformat = "%f:%l:%c:%m"
o.grepprg = "rg --vimgrep"
-- ╭─────────────────────────────╮
-- │ UI                          │
-- ╰─────────────────────────────╯
o.mouse = "a" -- Enable mouse support
o.cmdheight = 1 -- Command line height
o.showmode = false -- Don't show -- INSERT --
o.showtabline = 0 -- Hide tabline
o.pumheight = 10 -- Popup menu height
o.termguicolors = true -- Enable 24-bit colors
o.timeoutlen = 1000 -- Timeout for key mappings
o.updatetime = 500 -- CursorHold delay
o.title = true -- Set terminal title
o.confirm = true -- Confirm before closing modified buffer
o.fillchars = { eob = " " } -- Hide ~ at end of buffer
o.guifont = "monospace:h17" -- Font for GUI clients
o.winborder = "rounded" -- Window border style
o.laststatus = 3 -- global statusline
o.splitbelow = true -- Horizontal splits open below
o.splitright = true -- Vertical splits open right
o.splitkeep = "screen" -- Keep view stable when splitting
o.winminwidth = 5 -- Minimum window width
o.wildmode = "longest:full,full"
o.jumpoptions = "view"
o.shortmess:append({ W = true, I = true, c = true, C = true })
o.pumblend = 10
o.list = true
o.linebreak = true
-- ╭─────────────────────────────╮
-- │ Tabs & Indentation          │
-- ╰─────────────────────────────╯
o.expandtab = true -- Convert tabs to spaces
o.tabstop = 2 -- Spaces per tab
o.softtabstop = 2 -- Spaces per <Tab>
o.shiftwidth = 2 -- Spaces per indent
o.smartindent = true -- Smart auto-indenting
o.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
-- ╭─────────────────────────────╮
-- │ Line Numbers & Layout       │
-- ╰─────────────────────────────╯
o.number = true -- Show absolute line numbers
o.relativenumber = true -- Show relative line numbers
o.cursorline = true -- Highlight current line
o.breakindent = true -- Indent wrapped lines
o.wrap = false -- Disable line wrap
o.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard
-- ╭─────────────────────────────╮
-- │ Completion & Conceal        │
-- ╰─────────────────────────────╯
o.completeopt = { "menu", "menuone", "noselect" } -- Completion behavior
o.conceallevel = 0 -- Show `` in markdown files
