require("nvchad.mappings")

-- add yours here

-- local CodeSnap <const> = require("codesnap")
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "qq", "<ESC>")
-- window management
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
map("n", "<leader>sb", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })
--comment&trouble
map("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
map("n", "<leader>xw", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Open trouble workspace diagnostics" })
map(
    "n",
    "<leader>xd",
    "<cmd>Trouble diagnostics toggle filter.buf=0<CR>",
    { desc = "Open trouble document diagnostics" }
)
map("n", "<leader>xq", "<cmd>Trouble quickfix toggle<CR>", { desc = "Open trouble quickfix list" })
map("n", "<leader>xl", "<cmd>Trouble loclist toggle<CR>", { desc = "Open trouble location list" })
map("n", "<leader>xt", "<cmd>Trouble todo toggle<CR>", { desc = "Open todos in trouble" })
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")

map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")

map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
map("v", "<leader>cp", "<cmd>CodeSnap<cr>", { desc = "Save selected code snapshot into clipboard" })
map("n", "<leader>ss", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
map("n", "<leader>sb", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
--
-- terrminal
--
