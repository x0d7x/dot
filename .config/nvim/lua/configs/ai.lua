local ai = require("ai")
ai.setup({
    provider = "ollama",
    ollama = {
        model = "deepseek-r1:8b", -- You can start with smaller one like `gemma2` or `llama3.1`
        --endpoint = "http://192.168.2.47:11434", -- In case you access ollama from another machine
    },
    {
        -- ..
        -- Keymaps
        keymaps = {
            toggle = "<leader>ai", -- Toggle chat dialog
            send = "<CR>", -- Send message in normal mode
            close = "q", -- Close chat dialog
            clear = "<C-l>", -- Clear chat history
            stop_generate = "<C-c>", -- Stop generating
            previous_chat = "<leader>[", -- Open previous chat from history
            next_chat = "<leader>]", -- Open next chat from history
            inline_assist = "<leader>i", -- Run InlineAssist command with prompt
        },
    },
})
