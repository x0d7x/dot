return {
  -- "folke/tokyonight.nvim",
  -- opts = {
  --   transparent = true,
  --   styles = {
  --     sidebars = "transparent",
  --     floats = "transparent",
  --   },
  -- },
  -- add gruvbox
  -- { "ellisonleao/gruvbox.nvim", opts = {
  --   transparent_mode = true,
  --   priority = 1000,
  -- } },
  -- {
  --   "rebelot/kanagawa.nvim",
  --   opts = {
  --     transparent = true, -- do not set background color
  --     -- setup must be called before loading
  --     -- theme = "dragon",
  --     background = {
  --       dark = "dragon",
  --     },
  --   },
  --   config = function(_, opts)
  --     vim.o.background = "dark"
  --     require("kanagawa").setup(opts)
  --     vim.cmd.colorscheme("kanagawa")
  --   end,
  -- },
  --
  -- -- Configure LazyVim to load gruvbox
  -- {
  --   "maxmx03/solarized.nvim",
  --   priority = 1000,
  --   opts = {
  --     transparent = {
  --       enabled = true,
  --       pmenu = true,
  --       normal = true,
  --       normalfloat = true,
  --       neotree = true,
  --       nvimtree = true,
  --       whichkey = true,
  --       telescope = true,
  --       lazy = true,
  --     },
  --     variant = "spring", -- "spring" | "summer" | "autumn" | "winter" (default)
  --   },
  --   config = function(_, opts)
  --     vim.o.termguicolors = true
  --     vim.o.background = "dark"
  --     require("solarized").setup(opts)
  --     vim.cmd.colorscheme("solarized")
  --   end,
  -- },
  -- {
  --   "metalelf0/black-metal-theme-neovim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     require("black-metal").setup({
  --       -- optional configuration here
  --       -- require("black-metal").setup({
  --       -----MAIN OPTIONS-----
  --       --
  --       -- Can be one of: bathory | burzum | dark-funeral | darkthrone | emperor | gorgoroth | immortal | impaled-nazarene | khold | marduk | mayhem | nile | taake | venom
  --       theme = "darkthrone",
  --       -- Can be one of: 'light' | 'dark', or set via vim.o.background
  --       variant = "dark",
  --       -- Use an alternate, darker bg
  --       alt_bg = false,
  --       -- If true, docstrings will be highlighted like strings, otherwise they will be
  --       -- highlighted like comments. Note, behavior is dependent on the language server.
  --       colored_docstrings = true,
  --       -- If true, highlights the {sign,fold} column the same as cursorline
  --       cursorline_gutter = true,
  --       -- If true, highlights the gutter darker than the bg
  --       dark_gutter = false,
  --       -- if true favor treesitter highlights over semantic highlights
  --       favor_treesitter_hl = false,
  --       -- Don't set background of floating windows. Recommended for when using floating
  --       -- windows with borders.
  --       plain_float = true,
  --       -- Show the end-of-buffer character
  --       show_eob = true,
  --       -- If true, enable the vim terminal colors
  --       term_colors = true,
  --       -- Keymap (in normal mode) to toggle between light and dark variants.
  --       toggle_variant_key = nil,
  --       -- Don't set background
  --       transparent = false,
  --
  --       -----DIAGNOSTICS and CODE STYLE-----
  --       --
  --       diagnostics = {
  --         darker = true, -- Darker colors for diagnostic
  --         undercurl = true, -- Use undercurl for diagnostics
  --         background = true, -- Use background color for virtual text
  --       },
  --       -- The following table accepts values the same as the `gui` option for normal
  --       -- highlights. For example, `bold`, `italic`, `underline`, `none`.
  --       code_style = {
  --         comments = "italic",
  --         conditionals = "none",
  --         functions = "none",
  --         keywords = "none",
  --         headings = "bold", -- Markdown headings
  --         operators = "none",
  --         keyword_return = "none",
  --         strings = "none",
  --         variables = "bold",
  --       },
  --
  --       -----PLUGINS-----
  --       --
  --       -- The following options allow for more control over some plugin appearances.
  --       plugin = {
  --         lualine = {
  --           -- Bold lualine_a sections
  --           bold = true,
  --           -- Don't set section/component backgrounds. Recommended to not set
  --           -- section/component separators.
  --           plain = false,
  --         },
  --         cmp = { -- works for nvim.cmp and blink.nvim
  --           -- Don't highlight lsp-kind items. Only the current selection will be highlighted.
  --           plain = false,
  --           -- Reverse lsp-kind items' highlights in blink/cmp menu.
  --           reverse = false,
  --         },
  --       },
  --
  --       -- CUSTOM HIGHLIGHTS --
  --       --
  --       -- Override default colors
  --       colors = {},
  --       -- Override highlight groups
  --       highlights = {},
  --     })
  --     -- Convenience function that simply calls `:colorscheme <theme>` with the theme
  --     -- specified in your config.
  --     require("black-metal").load()
  --   end,
  -- },
  --
  -- {
  --   "webhooked/kanso.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     require("kanso").setup({
  --       bold = true, -- enable bold fonts
  --       italics = true, -- enable italics
  --       compile = false, -- enable compiling the colorscheme
  --       undercurl = true, -- enable undercurls
  --       commentStyle = { italic = true },
  --       functionStyle = {},
  --       keywordStyle = { italic = true },
  --       statementStyle = {},
  --       typeStyle = {},
  --       transparent = true, -- do not set background color
  --       dimInactive = false, -- dim inactive window `:h hl-NormalNC`
  --       terminalColors = true, -- define vim.g.terminal_color_{0,17}
  --       colors = { -- add/modify theme and palette colors
  --         palette = {},
  --         theme = { zen = {}, pearl = {}, ink = {}, all = {} },
  --       },
  --       overrides = function(colors) -- add/modify highlights
  --         return {}
  --       end,
  --       theme = "zen", -- Load "zen" theme
  --       background = { -- map the value of 'background' option to a theme
  --         dark = "zen", -- try "ink" !
  --         light = "pearl", -- try "mist" !
  --       },
  --     })
  --
  --     -- setup must be called before loading
  --     vim.cmd("colorscheme kanso")
  --   end,
  -- },
  -- {
  --   "uloco/bluloco.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   dependencies = { "rktjmp/lush.nvim" },
  --   opts = {},
  --   config = function()
  --     require("bluloco").setup({
  --       style = "dark", -- "auto" | "dark" | "light"
  --       transparent = true, -- if true, the background will be transparent
  --       italics = false,
  --       terminal = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
  --       guicursor = true,
  --       rainbow_headings = false, -- if you want different colored headings for each heading level
  --     })
  --     vim.opt.termguicolors = true
  --     vim.cmd("colorscheme bluloco")
  --     -- your optional config goes here, see below.
  --   end,
  -- },
  {
    "neanias/everforest-nvim",
    version = false,
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    -- Optional; default configuration will be used if setup isn't called.
    config = function()
      require("everforest").setup({
        -- Your config here
        ---Controls the "hardness" of the background. Options are "soft", "medium" or "hard".
        ---Default is "medium".
        background = "soft",
        ---How much of the background should be transparent. 2 will have more UI
        ---components be transparent (e.g. status line background)
        transparent_background_level = 2,
        ---Whether italics should be used for keywords and more.
        italics = true,
        ---Disable italic fonts for comments. Comments are in italics by default, set
        ---this to `true` to make them _not_ italic!
        disable_italic_comments = false,
        ---By default, the colour of the sign column background is the same as the as normal text
        ---background, but you can use a grey background by setting this to `"grey"`.
        sign_column_background = "none",
        ---The contrast of line numbers, indent lines, etc. Options are `"high"` or
        ---`"low"` (default).
        ui_contrast = "high",
        ---Dim inactive windows. Only works in Neovim. Can look a bit weird with Telescope.
        ---
        ---When this option is used in conjunction with show_eob set to `false`, the
        ---end of the buffer will only be hidden inside the active window. Inside
        ---inactive windows, the end of buffer filler characters will be visible in
        ---dimmed symbols. This is due to the way Vim and Neovim handle `EndOfBuffer`.
        dim_inactive_windows = false,
        ---Some plugins support highlighting error/warning/info/hint texts, by
        ---default these texts are only underlined, but you can use this option to
        ---also highlight the background of them.
        diagnostic_text_highlight = false,
        ---Which colour the diagnostic text should be. Options are `"grey"` or `"coloured"` (default)
        diagnostic_virtual_text = "coloured",
        ---Some plugins support highlighting error/warning/info/hint lines, but this
        ---feature is disabled by default in this colour scheme.
        diagnostic_line_highlight = false,
        ---By default, this color scheme won't colour the foreground of |spell|, instead
        ---colored under curls will be used. If you also want to colour the foreground,
        ---set this option to `true`.
        spell_foreground = false,
        ---Whether to show the EndOfBuffer highlight.
        show_eob = true,
        ---Style used to make floating windows stand out from other windows. `"bright"`
        ---makes the background of these windows lighter than |hl-Normal|, whereas
        ---`"dim"` makes it darker.
        ---
        ---Floating windows include for instance diagnostic pop-ups, scrollable
        ---documentation windows from completion engines, overlay windows from
        ---installers, etc.
        ---
        ---NB: This is only significant for dark backgrounds as the light palettes
        ---have the same colour for both values in the switch.
        float_style = "dim",
        ---Inlay hints are special markers that are displayed inline with the code to
        ---provide you with additional information. You can use this option to customize
        ---the background color of inlay hints.
        ---
        ---Options are `"none"` or `"dimmed"`.
        inlay_hints_background = "none",
        ---You can override specific highlights to use other groups or a hex colour.
        ---This function will be called with the highlights and colour palette tables.
        ---@param highlight_groups Highlights
        ---@param palette Palette
        on_highlights = function(highlight_groups, palette) end,
        ---You can override colours in the palette to use different hex colours.
        ---This function will be called once the base and background colours have
        ---been mixed on the palette.
        ---@param palette Palette
        colours_override = function(palette) end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
