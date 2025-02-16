return {
  "echasnovski/mini.files",
  opts = {
    -- Module mappings created only inside explorer.
    -- Use `''` (empty string) to not create one.
    mappings = {
      synchronize = "s",
    },
  },
  keys = function()
    return {
      {
        "<leader>e",
        function()
          require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
        end,
        desc = "Open mini.files (Directory of Current File)",
      },
      {
        "<leader>fM",
        function()
          require("mini.files").open(vim.uv.cwd(), true)
        end,
        desc = "Open mini.files (cwd)",
      },
    }
  end,
  -- make the last window expand to the eend of window
  -- by https://github.com/0xwal
  init = function()
    local function update_width_of_last_window()
      local state = MiniFiles.get_explorer_state()
      if not state then
        return
      end

      local windows = state.windows
      if #windows == 1 then
        return
      end

      local lastWindow = windows[#windows]
      local totalWidth = 0
      for _, win in ipairs(windows) do
        if lastWindow.win_id ~= win.win_id then
          local config = vim.api.nvim_win_get_config(win.win_id)
          totalWidth = totalWidth + config.width + 2
          config.zindex = 1
          vim.api.nvim_win_set_config(win.win_id, config)
        end
      end
      local width = math.abs(vim.o.columns - (totalWidth + 2))
      local config = vim.api.nvim_win_get_config(lastWindow.win_id)
      config.width = width
      vim.api.nvim_win_set_config(lastWindow.win_id, config)
    end
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesWindowUpdate",
      callback = function(_)
        update_width_of_last_window()
      end,
    })
  end,
}
