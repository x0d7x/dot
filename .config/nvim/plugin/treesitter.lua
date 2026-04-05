local pack = require("core.pack")

pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
})

require("nvim-treesitter").setup({
  sync_install = false,
  modules = {},
  fold = {
    enable = true,
  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = { enable = true },
  auto_install = true,
  ensure_installed = {
    "bash",
    "c",
    "html",
    "javascript",
    "json",
    "toml",
    "lua",
    "luadoc",
    "luap",
    "markdown",
    "markdown_inline",
    "python",
    "regex",
    "tsx",
    "typescript",
    "vue",
    "vim",
    "vimdoc",
    "yaml",
    "rust",
    "go",
    "gomod",
    "gowork",
    "gosum",
    "php",
    "astro",
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<leader>vv",
      node_incremental = "+",
      scope_incremental = false,
      node_decremental = "_",
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = { query = "@function.outer", desc = "around a function" },
        ["if"] = { query = "@function.inner", desc = "inner part of a function" },
        ["ac"] = { query = "@class.outer", desc = "around a class" },
        ["ic"] = { query = "@class.inner", desc = "inner part of a class" },
        ["ai"] = { query = "@conditional.outer", desc = "around an if statement" },
        ["ii"] = { query = "@conditional.inner", desc = "inner part of an if statement" },
        ["al"] = { query = "@loop.outer", desc = "around a loop" },
        ["il"] = { query = "@loop.inner", desc = "inner part of a loop" },
        ["ap"] = { query = "@parameter.outer", desc = "around parameter" },
        ["ip"] = { query = "@parameter.inner", desc = "inside a parameter" },
      },
      selection_modes = {
        ["@parameter.outer"] = "v",
        ["@parameter.inner"] = "v",
        ["@function.outer"] = "v",
        ["@conditional.outer"] = "V",
        ["@loop.outer"] = "V",
        ["@class.outer"] = "<c-v>",
      },
      include_surrounding_whitespace = false,
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_previous_start = {
        ["[f"] = { query = "@function.outer", desc = "Previous function" },
        ["[c"] = { query = "@class.outer", desc = "Previous class" },
        ["[p"] = { query = "@parameter.inner", desc = "Previous parameter" },
      },
      goto_next_start = {
        ["]f"] = { query = "@function.outer", desc = "Next function" },
        ["]c"] = { query = "@class.outer", desc = "Next class" },
        ["]p"] = { query = "@parameter.inner", desc = "Next parameter" },
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>a"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader>A"] = "@parameter.inner",
      },
    },
  },
})
