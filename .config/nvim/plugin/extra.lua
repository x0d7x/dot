local pack = require("core.pack")

pack.add({
	"https://github.com/folke/flash.nvim",
	{ src = "https://github.com/mistweaverco/bafa.nvim", version = "main" },
	"https://github.com/christoomey/vim-tmux-navigator",
	"https://github.com/folke/persistence.nvim",
	"https://github.com/nvzone/showkeys",
	"https://github.com/folke/todo-comments.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/uga-rosa/ccc.nvim",
	"https://github.com/folke/twilight.nvim",
	"https://github.com/Wansmer/treesj",
})

require("flash").setup({
	prompt = {
		enabled = false,
	},
})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash" })

vim.keymap.set({ "n", "x", "o" }, "S", function()
	require("flash").treesitter()
end, { desc = "Flash Treesitter" })

vim.keymap.set("o", "r", function()
	require("flash").remote()
end, { desc = "Remote Flash" })

vim.keymap.set({ "o", "x" }, "R", function()
	require("flash").treesitter_search()
end, { desc = "Treesitter Search" })

vim.keymap.set("c", "<c-s>", function()
	require("flash").toggle()
end, { desc = "Toggle Flash Search" })

require("persistence").setup({})

require("showkeys").setup({
	timeout = 1,
	maxkeys = 5,
	show_count = true,
	position = "bottom-center",
})

require("todo-comments").setup({})

require("ccc").setup({
	highlighter = {
		auto_enable = true,
		lsp = false,
	},
})

require("twilight").setup({})

if vim.fn.has("nvim-0.10.0") == 1 then
	pack.add({ "https://github.com/folke/ts-comments.nvim" })
	require("ts-comments").setup({})
end

require("treesj").setup({})
