return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre", "BufReadPre", "BufNewFile" }, -- uncomment for format on save
        config = function()
            require("configs.conform")
        end,
    },
    {
        "zapling/mason-conform.nvim",
        event = { "BufNewFile", "BufReadPre", "BufWritePre" },
        config = function()
            require("configs.mason-conform")
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("configs.treesitter")
        end,
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "antosha417/nvim-lsp-file-operations", config = true },
        config = function()
            require("nvchad.configs.lspconfig").defaults()
            require("configs.lspconfig")
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-lspconfig" },
        config = function()
            require("configs.mason-lspconfig")
        end,
    },
    {
        "stevearc/dressing.nvim",
        event = "VeryLazy",
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPre", "BufNewFile" },
        main = "ibl",
        opts = {
            indent = { char = "┊" },
        },
    },
    {
        "goolord/alpha-nvim",
        event = "VimEnter",
        config = function()
            require("configs.alpha")
        end,
    },
    {
        "kdheepak/lazygit.nvim",
        cmd = {
            "LazyGit",
            "LazyGitConfig",
            "LazyGitCurrentFile",
            "LazyGitFilter",
            "LazyGitFilterCurrentFile",
        },
        -- optional for floating window border decoration
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
    },
    {
        "szw/vim-maximizer",
        keys = {
            { "<leader>sm", "<cmd>MaximizerToggle<CR>", desc = "Maximize/minimize a split" },
        },
    },
    {
        "mfussenegger/nvim-lint",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("configs.lint")
        end,
    },
    {
        "rshkarin/mason-nvim-lint",
        event = "VeryLazy",
        dependencies = { "nvim-lint" },
        config = function()
            require("configs.mason-lint")
        end,
    },
    {
        "folke/todo-comments.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("configs.todo-comments")
        end,
    },
    {
        "numToStr/Comment.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "JoosepAlviste/nvim-ts-context-commentstring",
        },
        config = function()
            require("configs.comments")
        end,
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons", "folke/todo-comments.nvim" },
        opts = {
            focus = true,
        },
        cmd = "Trouble",
    },
    {
        "echasnovski/mini.hipatterns",
        event = "BufReadPre",
        opts = {},
    },
    {
        "vyfor/cord.nvim",
        build = "./build || .\\build",
        event = "VeryLazy",
        opts = {},
        config = function()
            require("configs.cord")
        end,
    },
    {
        "rmagatti/auto-session",
        cmd = { "SessionRestore", "SessionSave" },
        config = function()
            require("configs.auto-session")
        end,
    },
    {
        "christoomey/vim-tmux-navigator",
        cmd = {
            "TmuxNavigateLeft",
            "TmuxNavigateDown",
            "TmuxNavigateUp",
            "TmuxNavigateRight",
            "TmuxNavigatePrevious",
        },
    },
    {
        "mistricky/codesnap.nvim",
        build = "make",
        cmd = { "CodeSnap" },
        config = function()
            require("configs.snapcode")
        end,
    },
    {
        "rcarriga/nvim-notify",
        -- TODO: not working when add the command ?
        -- cmd = "notify",
        config = function()
            require("configs.notify")
        end,
    },
    {
        "folke/noice.nvim",
        event = "VeryLazy", --lazy-load
        opts = {
            -- add any options here
        },
        config = function()
            require("configs.noice")
        end,
        dependencies = {
            -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
            "MunifTanjim/nui.nvim",
            -- OPTIONAL:
            --   `nvim-notify` is only needed, if you want to use the notification view.
            --   If not available, we use `mini` as the fallback
            "rcarriga/nvim-notify",
        },
    },
    -- Markdown
    {
        "OXY2DEV/markview.nvim",
        lazy = false, -- Recommended
        -- ft = "markdown" -- If you decide to lazy-load anyway

        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
    },
    {
        "barrett-ruth/live-server.nvim",
        build = "pnpm add -g live-server",
        cmd = { "LiveServerStart", "LiveServerStop" },
        config = true,
    },
    --## AI ##--
    {
        "Exafunction/codeium.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "hrsh7th/nvim-cmp",
        },
        config = function()
            require("codeium").setup({})
        end,
    },
}
