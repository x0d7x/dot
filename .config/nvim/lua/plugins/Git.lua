-- Adds git related signs to the gutter, as well as utilities for managing changes
return {
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "" },
					change = { text = "|" },
					delete = { text = "" },
					topdelete = { text = "󰆴" },
					changedelete = { text = "󰍵" },
					untracked = { text = "" },
				},
				signs_staged = {
					add = { text = "" },
					change = { text = "" },
					delete = { text = "" },
					topdelete = { text = "" },
					changedelete = { text = "" },
					untracked = { text = "" },
				},
			})
		end,
	},
	{
		"sindrets/diffview.nvim",
		event = "VeryLazy",
		dependencies = {
			{ "nvim-tree/nvim-web-devicons", lazy = true },
		},
		-- to get it working wiith lazyvim
	},
	{
		"NeogitOrg/neogit",
		event = "VeryLazy",
		opts = {
			graph_style = "kitty",
		},
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration

			-- Only one of these is needed.
			-- "nvim-telescope/telescope.nvim", -- optional
			-- "ibhagwan/fzf-lua",              -- optional
			-- "echasnovski/mini.pick",         -- optional
			"folke/snacks.nvim", -- optional
		},
	},
}
