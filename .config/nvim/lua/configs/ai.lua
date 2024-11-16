local ai = require("avante")
ai.setup({
    provider = "groq",
    groq = {
        model = "llama-3.2-3b-preview",
        api_key_name = "GROQ_API_KEY",
    },
})
