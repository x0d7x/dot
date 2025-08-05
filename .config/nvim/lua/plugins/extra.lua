return {
	{
		"leath-dub/snipe.nvim",
		event = "VeryLazy",
		opts = {
			ui = {
				max_height = -1, -- -1 means dynamic height
				-- Where to place the ui window
				-- Can be any of "topleft", "bottomleft", "topright", "bottomright", "center", "cursor" (sets under the current cursor pos)
				position = "topleft",
				-- Override options passed to `nvim_open_win`
				-- Be careful with this as snipe will not validate
				-- anything you override here. See `:h nvim_open_win`
				-- for config options
				open_win_override = {
					-- title = "My Window Title",
					border = "single", -- use "rounded" for rounded border
				},

				-- Preselect the currently open buffer
				preselect_current = false,

				-- Set a function to preselect the currently open buffer
				-- E.g, `preselect = require("snipe").preselect_by_classifier("#")` to
				-- preselect alternate buffer (see :h ls and look at the "Indicators")
				preselect = nil, -- function (bs: Buffer[] [see lua/snipe/buffer.lua]) -> int (index)

				-- Changes how the items are aligned: e.g. "<tag> foo    " vs "<tag>    foo"
				-- Can be "left", "right" or "file-first"
				-- NOTE: "file-first" buts the file name first and then the directory name
				text_align = "left",
			},
			hints = {
				-- Charaters to use for hints (NOTE: make sure they don't collide with the navigation keymaps)
				dictionary = "saDfLewcmpghio",
			},

			navigate = {
				-- When the list is too long it is split into pages
				-- `[next|prev]_page` options allow you to navigate
				-- this list
				next_page = "J",
				prev_page = "K",

				-- You can also just use normal navigation to go to the item you want
				-- this option just sets the keybind for selecting the item under the
				-- cursor
				under_cursor = "l",

				-- In case you changed your mind, provide a keybind that lets you
				-- cancel the snipe and close the window.
				cancel_snipe = "q",

				-- Close the buffer under the cursor
				-- Remove "j" and "k" from your dictionary to navigate easier to delete
				-- NOTE: Make sure you don't use the character below on your dictionary
				close_buffer = "d",

				-- Open buffer in vertical split
				open_vsplit = "-",

				-- Open buffer in split, based on `vim.opt.splitbelow`
				open_split = "|",

				-- Change tag manually
				change_tag = "C",
			},
			-- The default sort used for the buffers
			-- Can be any of "last", (sort buffers by last accessed) "default" (sort buffers by its number)
			sort = "default",
		},
	},
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
			-- require("mini.surround").setup()

			require("mini.pairs").setup()

			-- local statusline = require("mini.statusline")
			-- statusline.setup({
			--   use_icons = vim.g.have_nerd_font,
			-- })
			-- ---@diagnostic disable-next-line: duplicate-set-field
			-- statusline.section_location = function()
			--   return "%2l:%-2v"
			-- end
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
