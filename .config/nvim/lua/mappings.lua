require("nvchad.mappings")

-- add yours here

-- local CodeSnap <const> = require("codesnap")
local map = vim.keymap.set

map("i", "qq", "<ESC>")
-- window management
map("n", "<leader>s|", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
map("n", "<leader>s-", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })
--comment&trouble
map("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
map("n", "<leader>tw", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Open trouble workspace diagnostics" })
map(
    "n",
    "<leader>td",
    "<cmd>Trouble diagnostics toggle filter.buf=0<CR>",
    { desc = "Open trouble document diagnostics" }
)
map("n", "<leader>tq", "<cmd>Trouble quickfix toggle<CR>", { desc = "Open trouble quickfix list" })
map("n", "<leader>tl", "<cmd>Trouble loclist toggle<CR>", { desc = "Open trouble location list" })
map("n", "<leader>tt", "<cmd>Trouble todo toggle<CR>", { desc = "Open todos in trouble" })
-- snipe maaps for going bttwen bufs
map("n", "<leader>sb", function()
    require("snipe").open_buffer_menu()
end, { desc = "Open Snipe buffer menu" })
-- to move the lines up & down in v mode
map("n", "<leader>st", "<cmd>Screenkey toggle<CR>", { desc = "Screenkey toogle" })
map("v", "K", ":m .-2<CR>==", { desc = "move the line up" })
map("v", "J", ":m .+1<CR>==", { desc = "move the line down" })
-- git key map
map("n", "<leader>gb", "<cmd>BlameToggle<CR>", { desc = "git blame inline" })
map("n", "<leader>lg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gh", "<cmd>Gitsigns preview_hunk<CR>", { desc = "git preview_hunk" })
-- tmux navigate
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
-- code Snap
map("n", "<leader>cp", "<cmd>CodeSnap<cr>", { desc = "Save selected code snapshot into clipboard" })
-- sessions
map("n", "<leader>ss", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
map("n", "<leader>sr", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" })
-- markdown
map("n", "<leader>mv", "<cmd>Markview<CR>", { desc = "markdown view" })
map("n", "<leader>ms", "<cmd>Markview splitEnable<CR>", { desc = "markdown splitEnb" })
map("n", "<leader>md", "<cmd>Markview splitDisable<CR>", { desc = "markdown splitDisable" })

-- live server
map("n", "<leader>ls", "<cmd>LiveServerStart<CR>", { desc = "Start live server" })
map("n", "<leader>lo", "<cmd>LiveServerStop<CR>", { desc = "Stop live server" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
--
-- terrminal
--
