-- local auto_session = require("auto_session")
require("auto-session").setup({
    auto_restore_enabled = false,
    auto_session_suppress_dirs = { "~/", "~/Downloads" },
})
