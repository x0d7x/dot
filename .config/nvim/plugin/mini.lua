local pack = require("core.pack")

pack.add({
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/echasnovski/mini.files",
})

require("mini.ai").setup({ n_lines = 500 })

require("mini.surround").setup({
  mappings = {
    add = "gsa",
    delete = "gsd",
    find = "gsf",
    find_left = "gsF",
    highlight = "gsh",
    replace = "gsr",
    update_n_lines = "gsn",
  },
})

require("mini.pairs").setup()

require("mini.files").setup({
  mappings = {
    synchronize = "s",
  },
})

local function update_width_of_last_window()
  local state = require("mini.files").get_explorer_state()
  if not state then
    return
  end

  local windows = state.windows
  if #windows == 1 then
    return
  end

  local last_window = windows[#windows]
  local total_width = 0
  for _, win in ipairs(windows) do
    if last_window.win_id ~= win.win_id then
      local config = vim.api.nvim_win_get_config(win.win_id)
      total_width = total_width + config.width + 2
      config.zindex = 1
      vim.api.nvim_win_set_config(win.win_id, config)
    end
  end
  local width = math.abs(vim.o.columns - (total_width + 2))
  local config = vim.api.nvim_win_get_config(last_window.win_id)
  config.width = width
  vim.api.nvim_win_set_config(last_window.win_id, config)
end

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesWindowUpdate",
  callback = function()
    update_width_of_last_window()
  end,
})
