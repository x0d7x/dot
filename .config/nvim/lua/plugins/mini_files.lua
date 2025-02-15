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
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesWindowUpdate",
      callback = function(args)
        local win_id = args.data.win_id

        -- Customize window-local settings
        local config = vim.api.nvim_win_get_config(win_id)
        config.border, config.title_pos = "rounded", "right"
        -- config.row = vim.o.lines - 2
        vim.api.nvim_win_set_config(win_id, config)

        local state = MiniFiles.get_explorer_state()

        if not state or not state.windows then
          print(vim.json.encode(state))
          return
        end

        local totalWidth = 0

        for _, win in ipairs(state.windows) do
          local width = vim.api.nvim_win_get_width(win.win_id)
          totalWidth = totalWidth + width
        end

        local lastWindow = state.windows[#state.windows]

        local restWidth = vim.o.columns - totalWidth

        vim.api.nvim_win_set_width(lastWindow.win_id, restWidth)
      end,
    })
  end,
}
