return {
	{
		"vague2k/vague.nvim",
		opts = {
			transparent = true, -- don't set background
			colors = {
				visual = "#cb945b",
				comment = "#666666",
			},
		},
		config = function(_, opts)
			require("vague").setup(opts)
			-- vim.cmd.colorscheme("vague")
		end,
	},
	{
		"oskarnurm/koda.nvim",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other start plugins
		opts = {
			transparent = true, -- enable for transparent backgrounds
			on_highlights = function(hl, c)
				hl.Comment = { fg = "#666666", italic = true }
			end,
		},
		config = function(_, opts)
			-- require("koda").setup({ transparent = true })
			require("koda").setup(opts)
			-- vim.cmd("colorscheme koda")
			vim.cmd("colorscheme koda-dark")
			-- vim.cmd("colorscheme koda-light")
			-- vim.cmd("colorscheme koda-moss")
			-- vim.cmd("colorscheme koda-glade")
		end,
	},
	{
		"nendix/zen.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			transparent = true, -- don't set background
		},
		config = function(_, opts)
			require("zen").setup(opts)
			-- vim.cmd.colorscheme("zen")
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
			-- vim.cmd([[colorscheme darcubox]])
		end,
	},
	{
		"rebelot/kanagawa.nvim",
		opts = {
			transparent = true, -- do not set background color
			-- setup must be called before loading
			terminalColors = true,
			theme = "dragon",
			background = {
				dark = "dragon",
			},
		},
		config = function(_, opts)
			require("kanagawa").setup(opts)
			-- vim.cmd("colorscheme kanagawa-dragon")
			vim.api.nvim_set_hl(0, "LineNr", { fg = "#666666", bg = "NONE" })
			vim.api.nvim_set_hl(0, "Comment", { fg = "#666666", italic = true })
			vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#CC7653", bold = true, bg = "NONE" })
		end,
	},
	{
		"motaz-shokry/gruvbox",
		url = "https://gitlab.com/motaz-shokry/gruvbox.nvim.git",
		name = "gruvbox",
		enabled = true,
		priority = 1000,
		opts = {
			variant = "soft", -- hard, medium, soft, light
			styles = {
				transparency = true,
			},
		},
		config = function(_, opts)
			require("gruvbox").setup(opts)
			-- vim.cmd("colorscheme gruvbox-soft")
		end,
	},
	{
		"darianmorat/gruvdark.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			transparent = true, -- Show or hide background
		},
		config = function(_, opts)
			require("gruvdark").setup(opts)
			-- vim.cmd.colorscheme("gruvdark")
		end,
	},
	{
		"connormxfadden/petrolnoir.nvim",
		priority = 1000, -- load before other UI plugins
		opts = {
			transparent = false, -- don't set background
		},
		config = function()
			-- vim.cmd.colorscheme("petrolnoir")
			vim.api.nvim_set_hl(0, "LineNr", { fg = "#666666" })
			vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#CC7653", bold = true })
		end,
	},
	{
		"mcauley-penney/techbase.nvim",
		priority = 1000,
		opts = {
			transparent = true, -- don't set background
		},
		config = function(_, opts)
			require("techbase").setup(opts)
			-- vim.cmd.colorscheme("techbase")
		end,
	},
}
