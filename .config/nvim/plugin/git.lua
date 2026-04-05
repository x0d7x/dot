local pack = require("core.pack")

pack.add({
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/NeogitOrg/neogit",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/folke/snacks.nvim",
})

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

require("diffview").setup({
  keymaps = {
    disable_defaults = false,
    view = {
      { "n", "q", "<cmd>tabclose<cr>", { desc = "close diffview" } },
    },
  },
})

require("neogit").setup({
  graph_style = "kitty",
})
