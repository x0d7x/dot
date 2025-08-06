return {
	{
		"vague2k/vague.nvim",
		opts = {
			transparent = true, -- don't set background
		},
		config = function(_, opts)
			require("vague").setup(opts)
			vim.cmd.colorscheme("vague")
		end,
	},
	{
		"ellisonleao/gruvbox.nvim",
		opts = {
			transparent_mode = true,
			priority = 1000,
		},
		config = function(_, opts)
			require("gruvbox").setup(opts)
			-- vim.cmd.colorscheme("gruvbox")
		end,
	},
	{
		"rebelot/kanagawa.nvim",
		opts = {
			transparent = true, -- do not set background color
			-- setup must be called before loading
			-- theme = "dragon",
			background = {
				dark = "dragon",
			},
		},
		config = function(_, opts)
			require("kanagawa").setup(opts)
			-- vim.cmd("colorscheme kanagawa-wave")
		end,
	},
}
