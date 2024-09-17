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
        build = "./build",
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
    --AI
    -- {
    --     "Exafunction/codeium.vim",
    --     event = "BufEnter",
    -- },
    --## markdown plug ##--
    {
        "ellisonleao/glow.nvim",
        config = true,
        cmd = "Glow",
    },
    {
        "barrett-ruth/live-server.nvim",
        build = "pnpm add -g live-server",
        cmd = { "LiveServerStart", "LiveServerStop" },
        config = true,
    },
    --## AI ##--
    {
        "yetone/avante.nvim",
        event = "VeryLazy",
        lazy = false,
        version = false, -- set this if you want to always pull the latest change
        opts = {
            provider = "groq",
            vendors = {
                groq = {
                    endpoint = "https://api.openai.com/v1/chat/completions",
                    model = "llama3-70b-8192",
                    api_key_name = "GROQ_API_KEY",
                    parse_curl_args = function(opts, code_opts)
                        return {
                            url = opts.endpoint,
                            headers = {
                                ["Accept"] = "application/json",
                                ["Content-Type"] = "application/json",
                                ["Authorization"] = "Bearer " .. os.getenv(opts.api_key_name),
                            },
                            body = {
                                model = opts.model,
                                messages = { -- you can make your own message, but this is very advanced
                                    { role = "system", content = code_opts.system_prompt },
                                    {
                                        role = "user",
                                        content = require("avante.providers.openai").get_user_message(code_opts),
                                    },
                                },
                                temperature = 0,
                                max_tokens = 4096,
                                stream = true, -- this will be set by default.
                            },
                        }
                    end,
                    parse_response_data = function(data_stream, event_state, opts)
                        require("avante.providers").openai.parse_response(data_stream, event_state, opts)
                    end,
                },
            },
            -- add any opts here
        },
        -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
        build = "make BUILD_FROM_SOURCE=true",
        -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
        dependencies = {
            "stevearc/dressing.nvim",
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            --- The below dependencies are optional,
            "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
            "zbirenbaum/copilot.lua", -- for providers='copilot'
            {
                -- support for image pasting
                "HakonHarnes/img-clip.nvim",
                event = "VeryLazy",
                opts = {
                    -- recommended settings
                    default = {
                        embed_image_as_base64 = false,
                        prompt_for_file_name = false,
                        drag_and_drop = {
                            insert_mode = true,
                        },
                        -- required for Windows users
                        use_absolute_path = true,
                    },
                },
            },
            {
                -- Make sure to set this up properly if you have lazy=true
                "MeanderingProgrammer/render-markdown.nvim",
                opts = {
                    file_types = { "markdown", "Avante" },
                },
                ft = { "markdown", "Avante" },
            },
        },
    },
}
