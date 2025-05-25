return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
NNNNNNNN        NNNNNNNN                           iiii                          
N:::::::N       N::::::N                          i::::i                         
N::::::::N      N::::::N                           iiii                          
N:::::::::N     N::::::N                                                         
N::::::::::N    N::::::Nvvvvvvv           vvvvvvviiiiiii    mmmmmmm    mmmmmmm   
N:::::::::::N   N::::::N v:::::v         v:::::v i:::::i  mm:::::::m  m:::::::mm 
N:::::::N::::N  N::::::N  v:::::v       v:::::v   i::::i m::::::::::mm::::::::::m
N::::::N N::::N N::::::N   v:::::v     v:::::v    i::::i m::::::::::::::::::::::m
N::::::N  N::::N:::::::N    v:::::v   v:::::v     i::::i m:::::mmm::::::mmm:::::m
N::::::N   N:::::::::::N     v:::::v v:::::v      i::::i m::::m   m::::m   m::::m
N::::::N    N::::::::::N      v:::::v:::::v       i::::i m::::m   m::::m   m::::m
N::::::N     N:::::::::N       v:::::::::v        i::::i m::::m   m::::m   m::::m
N::::::N      N::::::::N        v:::::::v        i::::::im::::m   m::::m   m::::m
N::::::N       N:::::::N         v:::::v         i::::::im::::m   m::::m   m::::m
N::::::N        N::::::N          v:::v          i::::::im::::m   m::::m   m::::m
NNNNNNNN         NNNNNNN           vvv           iiiiiiiimmmmmm   mmmmmm   mmmmmm
]],
      },
    },
    picker = {
      layout = {
        cycle = false,
        preset = "ivy",
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
