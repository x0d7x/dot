-- Adds git related signs to the gutter, as well as utilities for managing changes
return {
	{
		"lewis6991/gitsigns.nvim",
		lazy = false,
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
		opts = {
			keymaps = {
				disable_defaults = false, -- Disable the default keymaps
				view = {
					{ "n", "q", "<cmd>tabclose<cr>", { desc = "close diffview" } },
				},
			},
		},
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

			-- Only one of these is needed.
			-- "nvim-telescope/telescope.nvim", -- optional
			-- "ibhagwan/fzf-lua",              -- optional
			-- "echasnovski/mini.pick",         -- optional
			"folke/snacks.nvim", -- optional
		},
	},
}
