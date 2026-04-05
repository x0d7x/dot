local pack = require("core.pack")

pack.add({ "https://github.com/folke/snacks.nvim" })

local Snacks = require("snacks")

Snacks.setup({
  dashboard = { enabled = false },
  bigfile = { enabled = true },
  dim = {
    enabled = true,
    padding = { 4, 4 },
    alpha = 0.4,
    exclude = {},
  },
  indent = { enabled = false },
  input = { enabled = false },
  notifier = {
    enabled = true,
    timeout = 3000,
  },
  quickfile = { enabled = true },
  notify = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = true },
  scratch = { enabled = true },
  words = { enabled = true },
  toggle = { enabled = true },
  image = { enabled = true },
  zen = { enabled = true },
  lazygit = { enabled = false },
  animate = { enabled = false },
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    _G.dd = function(...)
      Snacks.debug.inspect(...)
    end
    _G.bt = function()
      Snacks.debug.backtrace()
    end
    vim.print = _G.dd
    Snacks.dim()
    Snacks.toggle.scroll():map("<leader>uS")
    Snacks.toggle.animate():map("<leader>ua")
    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
    Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
    Snacks.toggle.diagnostics():map("<leader>ud")
    Snacks.toggle.line_number():map("<leader>ul")
    Snacks.toggle
      .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
      :map("<leader>uc")
    Snacks.toggle.treesitter():map("<leader>uT")
    Snacks.toggle
      .option("background", { off = "light", on = "dark", name = "Dark Background" })
      :map("<leader>ub")
    Snacks.toggle.inlay_hints():map("<leader>uh")
    Snacks.toggle.indent():map("<leader>ug")
    Snacks.toggle.profiler():map("<leader>pp")
    Snacks.toggle.profiler_highlights():map("<leader>ph")
    Snacks.toggle.zen():map("<leader>uz")
    Snacks.toggle.zoom():map("<leader>wm")
  end,
})
