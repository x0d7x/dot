return {
  {
    "leath-dub/snipe.nvim",
    opts = {
      ui = {
        max_height = -1, -- -1 means dynamic height
        -- Where to place the ui window
        -- Can be any of "topleft", "bottomleft", "topright", "bottomright", "center", "cursor" (sets under the current cursor pos)
        position = "topleft",
        -- Override options passed to `nvim_open_win`
        -- Be careful with this as snipe will not validate
        -- anything you override here. See `:h nvim_open_win`
        -- for config options
        open_win_override = {
          -- title = "My Window Title",
          border = "single", -- use "rounded" for rounded border
        },

        -- Preselect the currently open buffer
        preselect_current = false,

        -- Set a function to preselect the currently open buffer
        -- E.g, `preselect = require("snipe").preselect_by_classifier("#")` to
        -- preselect alternate buffer (see :h ls and look at the "Indicators")
        preselect = nil, -- function (bs: Buffer[] [see lua/snipe/buffer.lua]) -> int (index)

        -- Changes how the items are aligned: e.g. "<tag> foo    " vs "<tag>    foo"
        -- Can be "left", "right" or "file-first"
        -- NOTE: "file-first" buts the file name first and then the directory name
        text_align = "left",
      },
      hints = {
        -- Charaters to use for hints (NOTE: make sure they don't collide with the navigation keymaps)
        dictionary = "saDfLewcmpghio",
      },

      navigate = {
        -- When the list is too long it is split into pages
        -- `[next|prev]_page` options allow you to navigate
        -- this list
        next_page = "J",
        prev_page = "K",

        -- You can also just use normal navigation to go to the item you want
        -- this option just sets the keybind for selecting the item under the
        -- cursor
        under_cursor = "l",

        -- In case you changed your mind, provide a keybind that lets you
        -- cancel the snipe and close the window.
        cancel_snipe = "q",

        -- Close the buffer under the cursor
        -- Remove "j" and "k" from your dictionary to navigate easier to delete
        -- NOTE: Make sure you don't use the character below on your dictionary
        close_buffer = "d",

        -- Open buffer in vertical split
        open_vsplit = "-",

        -- Open buffer in split, based on `vim.opt.splitbelow`
        open_split = "|",

        -- Change tag manually
        change_tag = "C",
      },
      -- The default sort used for the buffers
      -- Can be any of "last", (sort buffers by last accessed) "default" (sort buffers by its number)
      sort = "default",
    },
  },
}
