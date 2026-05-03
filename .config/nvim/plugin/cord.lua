local pack = require("core.pack")

pack.add({ "https://github.com/vyfor/cord.nvim" })

require("cord").setup({
  display = { theme = "atom", flavor = "dark" },
  editor = {
    client = "vim",
    tooltip = "the quick brown fox jumps over the lazy dog",
  },
  text = {
    editing = "[ Coding a ${filename} ] 🚀",
  },
  variables = true,
})
