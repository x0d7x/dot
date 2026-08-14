local pack = require("core.pack")

pack.add({ "https://github.com/folke/which-key.nvim" })

require("which-key").setup({
  preset = "helix",
  delay = 300,
  icons = {
    rules = false,
    breadcrumb = " ",
    separator = "󱦰  ",
    group = " ",
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
      { "<leader>f", group = "[F]ind" },
      { "<leader>g", group = "[G]it" },
      { "<leader>R", group = "[R]eplace" },
      { "<leader>l", group = "[L]SP" },
      { "<leader>c", group = "[C]ode", mode = { "n", "x" } },
      { "<leader>t", group = "[T]oggle" },
      { "<leader>p", group = "[P]rofiler" },
      { "<leader>D", group = "[D]ebugger" },
      { "<leader>s", group = "[S]earch" },
      { "<leader>x", group = "[D]iagnostics/quickfix (Trouble)", icon = { icon = "󱖫 ", color = "green" } },
      { "<leader>u", group = "[U]i", icon = { icon = "󰙵 ", color = "cyan" } },
      { "<leader>b", group = "[B]uffer" },
      { "<leader>n", group = "[N]otify" },
      { "<leader>q", group = "[q]uit" },
      { "<leader>w", group = "[W]ind" },
      { "[", group = "prev" },
      { "]", group = "next" },
      { "g", group = "goto" },
    },
  },
})

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
