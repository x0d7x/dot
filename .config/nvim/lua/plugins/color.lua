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
  { "ellisonleao/gruvbox.nvim", opts = {
    transparent_mode = true,
  } },
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
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
