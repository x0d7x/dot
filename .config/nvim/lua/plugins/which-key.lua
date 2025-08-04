return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "helix",
		delay = 300,
		icons = {
			rules = false,
			breadcrumb = " ", -- symbol used in the command line area that shows your active key combo
			separator = "󱦰  ", -- symbol used between a key and it's label
			group = " ", -- symbol prepended to a group
		},
		plugins = {
			spelling = {
				enabled = false,
			},
		},
		win = {
			height = {
				max = math.huge,
			},
		},
		spec = {
			{
				mode = { "n", "v" },
				{ "<leader>f", group = "Find" },
				{ "<leader>g", group = "Git" },
				{ "<leader>R", group = "Replace" },
				{ "<leader>l", group = "LSP" },
				{ "<leader>c", group = "Code" },
				{ "<leader>t", group = "Test" },
				{ "<leader>D", group = "Debugger" },
				{ "<leader>s", group = "Search" },
				{ "<leader>x", group = "diagnostics/quickfix (Trouble)", icon = { icon = "󱖫 ", color = "green" } },
				{ "<leader>u", group = "UI", icon = { icon = "󰙵 ", color = "cyan" } },
				{ "<leader>b", group = "Buffer" },
				{ "<leader>n", group = "Notify" },
				{ "<leader>q", group = "quit" },
				{ "<leader>w", group = "Wind" },
				{ "[", group = "prev" },
				{ "]", group = "next" },
				{ "g", group = "goto" },
			},
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
