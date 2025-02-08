local logsitter = require("logsitter")
local javascript_logger = require("logsitter.lang.javascript")
local map = vim.keymap.set

-- tell logsitter to use the javascript_logger when the filetype is svelte
logsitter.register(javascript_logger, { "svelte", "astro" })

map("n", "<leader>lc", function()
    logsitter.log()
end, { desc = "Logsitter" })
