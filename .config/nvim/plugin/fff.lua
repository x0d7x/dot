local pack = require("core.pack")

pack.add({ "https://github.com/dmtrKovalenko/fff.nvim" })

require("fff").setup({
  debug = {
    enabled = true,
    show_scores = true,
  },
  keymaps = {
    close = "q",
    move_up = "<C-k>",
    move_down = "<C-j>",
  },
  layout = {
    prompt_position = "bottom",
  },
})

vim.keymap.set("n", "fm", function()
  require("fff").live_grep({ query = vim.fn.expand("<cword>") })
end, { desc = "Search current word" })
