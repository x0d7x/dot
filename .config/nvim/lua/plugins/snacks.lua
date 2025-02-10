return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░             ░▒▓█▓▒░░▒▓███████▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░        
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░        
░▒▓██████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓███████▓▒░              ░▒▓█▓▒░░▒▓██████▓▒░  
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓██▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░ 
░▒▓█▓▒░       ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓██▓▒░░▒▓██████▓▒░░▒▓███████▓▒░  
                                                                                       
             ]],
      },
    },
    picker = {
      layout = {
        cycle = false,
        preset = "vertical",
      },
      matcher = {
        frecency = true,
      },
      debug = {
        scores = true, -- show scores in the list
      },
      layouts = {
        vertical = {
          layout = {
            width = 0.7,
          },
        },
        select = {
          preview = true,
        },
        dropdown = {
          layout = {
            width = 0.6,
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader>sk",
      function()
        Snacks.picker.keymaps({ layout = "vertical" })
      end,
      desc = "Keymaps",
    },
    {
      "<leader><space>",
      function()
        Snacks.picker.files({
          layout = "vertical",
          -- on_show = function()
          --   vim.cmd.stopinsert()
          -- end,
        })
      end,
      desc = "Find Files (Root Dir)",
    },
    {
      "<leader>,",
      function()
        Snacks.picker.buffers({
          on_show = function()
            vim.cmd.stopinsert()
          end,
        })
      end,
      desc = "open buffers pick",
    },
  },
}
