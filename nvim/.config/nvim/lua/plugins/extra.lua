return {
	{
		"NStefan002/screenkey.nvim",
		event = "VeryLazy",
		version = "*", -- or branch = "dev", to use the latest commit
		opts = {
			win_opts = {
				col = vim.o.columns - 1,
				relative = "editor",
				anchor = "SE",
				width = 25,
				height = 3,
				border = "none",
				title = "",
				title_pos = "center",
				style = "minimal",
				focusable = false,
				noautocmd = true,
			},
			compress_after = 3,
			clear_after = 2,
			disable = {
				filetypes = {},
				buftypes = {},
				events = false,
			},
			show_leader = false,
			group_mappings = false,
			display_infront = {},
			display_behind = {},
			filter = function(keys)
				return keys
			end,
			keys = {
				["<TAB>"] = "󰌒",
				["<CR>"] = "󰌑",
				["<ESC>"] = "Esc",
				["<SPACE>"] = "␣",
				["<BS>"] = "󰌥",
				["<DEL>"] = "Del",
				["<LEFT>"] = "",
				["<RIGHT>"] = "",
				["<UP>"] = "",
				["<DOWN>"] = "",
				["<HOME>"] = "Home",
				["<END>"] = "End",
				["<PAGEUP>"] = "PgUp",
				["<PAGEDOWN>"] = "PgDn",
				["<INSERT>"] = "Ins",
				["<F1>"] = "󱊫",
				["<F2>"] = "󱊬",
				["<F3>"] = "󱊭",
				["<F4>"] = "󱊮",
				["<F5>"] = "󱊯",
				["<F6>"] = "󱊰",
				["<F7>"] = "󱊱",
				["<F8>"] = "󱊲",
				["<F9>"] = "󱊳",
				["<F10>"] = "󱊴",
				["<F11>"] = "󱊵",
				["<F12>"] = "󱊶",
				["CTRL"] = "Ctrl",
				["ALT"] = "Alt",
				["SUPER"] = "󰘳",
				["<leader>"] = "<leader>",
			},
		},
	},
	-- moving around code
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		---@type Flash.Config
		opts = {
			prompt = {
				enabled = false,
			},
		},
    -- stylua: ignore
    keys = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
      { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
    },
	},
	-- tmux move with nevim
	{
		"christoomey/vim-tmux-navigator",
		event = "VeryLazy",
	},
	-- sessions
	{
		"folke/persistence.nvim",
		event = "BufReadPre", -- this will only start session saving when an actual file was opened
		opts = {
			-- add any custom options here
		},
	},

	{
		"j-hui/fidget.nvim",
		opts = {
			notification = {
				window = {
					winblend = 0, -- Background color opacity in the notification window
				},
			},
		},
	},
	-- moving around code
	{
		"echasnovski/mini.nvim",
		event = "VeryLazy",
		config = function()
			-- Better Around/Inside textobjects
			--
			-- Examples:
			--  - va)  - [V]isually select [A]round [)]paren
			--  - yinq - [Y]ank [I]nside [N]ext [']quote
			--  - ci'  - [C]hange [I]nside [']quote
			require("mini.ai").setup({ n_lines = 500 })

			-- Add/delete/replace surroundings (brackets, quotes, etc.)
			--
			-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
			-- - sd'   - [S]urround [D]elete [']quotes
			-- - sr)'  - [S]urround [R]eplace [)] [']
			require("mini.surround").setup({
				mappings = {
					add = "gsa", -- Add surrounding in Normal and Visual modes
					delete = "gsd", -- Delete surrounding
					find = "gsf", -- Find surrounding (to the right)
					find_left = "gsF", -- Find surrounding (to the left)
					highlight = "gsh", -- Highlight surrounding
					replace = "gsr", -- Replace surrounding
					update_n_lines = "gsn", -- Update `n_lines`
				},
			})

			require("mini.pairs").setup()
		end,
	},
	-- taking pic for the code
	{
		"mistricky/codesnap.nvim",
		build = "make",
		opts = {
			save_path = "~/Developer/codepic",
			has_breadcrumbs = true,
			bg_theme = "peach",
			watermark = "@x0d7x",
		},
	},
	-- dimming
	{
		"folke/twilight.nvim",
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	-- import lib size
	{
		{
			"barrett-ruth/import-cost.nvim",
			event = "VeryLazy",
			build = "sh install.sh bun",
			-- if on windows
			-- build = 'pwsh install.ps1 yarn',
			config = true,
		},
	},
	{
		"folke/ts-comments.nvim",
		opts = {},
		event = "VeryLazy",
		enabled = vim.fn.has("nvim-0.10.0") == 1,
	},
}
