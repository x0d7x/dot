local pack = require("core.pack")

pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup({
  mode = "workspace_diagnostics",
  position = "bottom",
  height = 15,
  padding = false,
  action_keys = {
    close = "q",
    cancel = "<esc>",
    refresh = "r",
    jump = { "<cr>", "<tab>" },
    open_split = { "<c-x>" },
    open_vsplit = { "<c-v>" },
    open_tab = { "<c-t>" },
    jump_close = { "o" },
    toggle_mode = "m",
    toggle_preview = "P",
    hover = "K",
    preview = "p",
    close_folds = { "zM" },
    open_folds = { "zR" },
    toggle_fold = { "za" },
  },
  auto_jump = {},
  use_diagnostic_signs = true,
})

local ok_snacks, snacks = pcall(require, "snacks")
if ok_snacks and type(snacks.setup) == "function" then
  local ok_trouble, trouble_snacks = pcall(require, "trouble.sources.snacks")
  if ok_trouble then
    snacks.setup({
      picker = {
        actions = trouble_snacks.actions,
        win = {
          input = {
            keys = {
              ["<c-t>"] = {
                "trouble_open",
                mode = { "n", "i" },
              },
            },
          },
        },
      },
    })
  end
end
