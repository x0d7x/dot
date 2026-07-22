vim.pack.add({
	{ src = "https://github.com/Isrothy/neominimap.nvim" },
})

-- The following options are recommended when layout == "float"
-- vim.opt.wrap = false
-- vim.opt.sidescrolloff = 36 -- Set a large value

--- Put your configuration here
---@type Neominimap.UserConfig
vim.g.neominimap = {
	auto_enable = true,
}

-- Keymaps
local opts = { noremap = true, silent = true }

-- Global toggle
vim.keymap.set("n", "<leader>nm", "<cmd>Neominimap Toggle<cr>", opts)

-- Window toggle
vim.keymap.set("n", "<leader>nw", "<cmd>Neominimap WinToggle<cr>", opts)

-- Buffer toggle
vim.keymap.set("n", "<leader>nb", "<cmd>Neominimap BufToggle<cr>", opts)

-- Focus / unfocus the minimap
vim.keymap.set("n", "<leader>nf", "<cmd>Neominimap ToggleFocus<cr>", opts)
