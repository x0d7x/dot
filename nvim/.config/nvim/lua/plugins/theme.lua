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
		"Koalhack/darcubox-nvim",
		opts = {
			options = {
				transparent = true, -- don't set background
				styles = {
					comments = { italic = true }, -- italic
					functions = { bold = true }, -- bold
					keywords = { italic = true },
					types = { italic = true, bold = true }, -- italics and bold
				},
			},
		},
		config = function(_, opts)
			require("darcubox").setup(opts)
			-- vim.cmd("colorscheme darcubox")
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
	{
		"motaz-shokry/gruvbox",
		url = "https://gitlab.com/motaz-shokry/gruvbox.nvim.git",
		name = "gruvbox",
		priority = 1000,
		opts = {
			variant = "hard", -- hard, medium, soft, light
			styles = {
				transparency = true,
			},
		},
		config = function(_, opts)
			require("gruvbox").setup(opts)
			-- vim.cmd("colorscheme gruvbox-hard")
		end,
	},
}
