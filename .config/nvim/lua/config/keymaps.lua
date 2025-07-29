-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
local del = vim.keymap.del
local opts = { noremap = true, silent = true }

map("i", "qq", "<ESC>", { noremap = false })
map("n", "<leader>se", "<cmd>Screenkey toggle<CR>", { desc = "Screenkey toogle" })
map("n", "<leader>bs", function()
  require("snipe").open_buffer_menu()
end, { desc = "Open Snipe buffer menu" })
-- tmux navigate
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
map("n", "cv", function()
  local new_config = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = new_config })
end, { desc = "Toggle diagnostic virtual_lines" })
-- Normal-mode commands
-- map("n", "<S-j>", ":MoveLine(1)<CR>", opts)
map("n", "<S-l>", ":MoveLine(-1)<CR>", opts)
map("n", "<leader>wf", ":MoveWord(1)<CR>", opts)

map("n", "<leader>wb", ":MoveWord(-1)<CR>", opts)
-- Visual-mode commands
-- map("v", "<S-j>", ":MoveBlock(1)<CR>", opts)
map("v", "<S-l>", ":MoveBlock(-1)<CR>", opts)
