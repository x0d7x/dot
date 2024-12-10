pcall(function()
    dofile(vim.g.base46_cache .. "syntax")
    dofile(vim.g.base46_cache .. "treesitter")
end)

local options = {
    ensure_installed = {
        "bash",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "printf",
        "toml",
        "vim",
        "vimdoc",
        "yaml",
        "tsx",
        "javascript",
        "html",
        "css",
        "typescript",
        "python",
        "json",
        "gitignore",
        "regex",
    },

    highlight = {
        enable = true,
        use_languagetree = true,
    },

    indent = { enable = true },

    autotag = {
        enable = true,
    },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
        },
    },
}

require("nvim-treesitter.configs").setup(options)
return options
