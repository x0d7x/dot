local pack = require("core.pack")

pack.add({
	"https://github.com/metalelf0/black-metal-theme-neovim",
	"https://github.com/vague2k/vague.nvim",
	"https://github.com/WTFox/luna.nvim",
	"https://github.com/Aejkatappaja/sora",
	"https://github.com/oskarnurm/koda.nvim",
	"https://github.com/nendix/zen.nvim",
	"https://github.com/Koalhack/darcubox-nvim",
	"https://github.com/rebelot/kanagawa.nvim",
	{ src = "https://gitlab.com/motaz-shokry/gruvbox.nvim.git", name = "gruvbox" },
	"https://github.com/darianmorat/gruvdark.nvim",
	"https://github.com/connormxfadden/petrolnoir.nvim",
	"https://github.com/mcauley-penney/techbase.nvim",
	"https://github.com/54L1M/Oshen.nvim",
	"https://github.com/Aejkatappaja/cendre",
	"https://github.com/craftzdog/solarized-osaka.nvim",
})
require("cendre").setup({
	transparent = true, -- set false for opaque background
	background = "hard",
})
require("luna").setup({
	transparent = true,
	accent = 1.0, -- 0-1, blends syntax accents toward grey_light; 1 = full color
	plugins = {
		all = true, -- enable every plugin integration unconditionally
		auto = true, -- when plugins.all is false, autodetect via lazy.nvim
	},
	on_colors = function(colors) end,
	on_highlights = function(highlights, colors) end,
})
require("solarized-osaka").setup({
	-- your configuration comes here
	-- or leave it empty to use the default settings
	style = "", -- The default dark style. Set to `vivid` for a higher-contrast variant that stays readable in bright environments
	light_style = "light", -- The theme is used when the background is set to light
	transparent = true, -- Enable this to disable setting the background color
	terminal_colors = true, -- Configure the colors used when opening a `:terminal` in [Neovim](https://github.com/neovim/neovim)
	styles = {
		-- Style to be applied to different syntax groups
		-- Value is any valid attr-list value for `:help nvim_set_hl`
		comments = { italic = true },
		keywords = { italic = true },
		functions = {},
		variables = {},
		-- Background styles. Can be "dark", "transparent" or "normal"
		sidebars = "dark", -- style for sidebars, see below
		floats = "transparent", -- style for floating windows
	},
	sidebars = { "qf", "help" }, -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
	vivid_brightness = 0.3, -- Adjusts how far the **Vivid** style brightens text colors. Number between 0 and 1, from the default palette to white
	hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
	dim_inactive = false, -- dims inactive windows
	lualine_bold = false, -- When `true`, section headers in the lualine theme will be bold

	--- You can override specific color groups to use other groups or a hex color
	--- function will be called with a ColorScheme table
	---@param colors ColorScheme
	on_colors = function(colors) end,

	--- You can override specific highlights to use other groups or a hex color
	--- function will be called with a Highlights and ColorScheme table
	---@param highlights Highlights
	---@param colors ColorScheme
	on_highlights = function(highlights, colors) end,
})
require("oshen").setup({
	transparent = true, -- set false for opaque background
})
require("black-metal").setup({ -- Can be one of: bathory | burzum | dark-funeral | darkthrone | emperor | gorgoroth | immortal | impaled-nazarene | khold | marduk | mayhem | nile | taake | thyrfing | venom | windir
	theme = "bathory",
	-- Can be one of: 'light' | 'dark', or set via vim.o.background
	variant = "dark",
	-- Use an alternate, lighter bg
	alt_bg = false,
	-- If true, docstrings will be highlighted like strings, otherwise they will be
	-- highlighted like comments. Note, behavior is dependent on the language server.
	colored_docstrings = true,
	-- If true, highlights the {sign,fold} column the same as cursorline
	cursorline_gutter = true,
	-- If true, highlights the gutter darker than the bg
	dark_gutter = false,
	-- if true favor treesitter highlights over semantic highlights
	favor_treesitter_hl = false,
	-- Don't set background of floating windows. Recommended for when using floating
	-- windows with borders.
	plain_float = true,
	-- Show the end-of-buffer character
	show_eob = true,
	-- If true, enable the vim terminal colors
	term_colors = true,
	-- Keymap (in normal mode) to toggle between light and dark variants.
	toggle_variant_key = nil,
	-- Don't set background
	transparent = true,
})
-- require("black-metal").load()
require("vague").setup({
	transparent = true,
	colors = {
		visual = "#cb945b",
		comment = "#666666",
	},
})

require("sora").setup({ transparent = true })

require("koda").setup({
	transparent = true,
	on_highlights = function(hl)
		hl.Comment = { fg = "#666666", italic = true }
	end,
})

require("zen").setup({ transparent = false })

require("darcubox").setup({
	options = {
		transparent = true,
		styles = {
			comments = { italic = true },
			functions = { bold = true },
			keywords = { italic = true },
			types = { italic = true, bold = true },
		},
	},
})

require("kanagawa").setup({
	transparent = true,
	terminalColors = true,
	theme = "dragon",
	background = {
		dark = "dragon",
	},
})

require("gruvbox").setup({
	variant = "soft",
	styles = {
		transparency = true,
	},
})

require("gruvdark").setup({ transparent = false })

require("techbase").setup({ transparent = true })

require("petrolnoir").setup({ transparent = true })
-- vim.api.nvim_set_hl(0, "CursorLine", {
-- fg = "#ffffff",
-- bg = "#CC7653",
-- bold = true,
-- })
-- vim.api.nvim_set_hl(0, "LineNr", { fg = "#666666", bg = "NONE" })
-- vim.api.nvim_set_hl(0, "Comment", { fg = "#666666", italic = true })
-- vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#CC7653", bold = true, bg = "NONE" })
-- vim.cmd.colorscheme("cendre")
vim.cmd([[colorscheme solarized-osaka]])
-- vim.cmd.colorscheme("luna")
-- vim.cmd.colorscheme("Oshen")
-- vim.cmd.colorscheme("vague")
-- vim.cmd("colorscheme sora")
-- vim.cmd("colorscheme koda-dark")
-- vim.cmd("colorscheme zen")
-- vim.cmd.colorscheme("gruvbox")
-- vim.cmd.colorscheme("techbase")
