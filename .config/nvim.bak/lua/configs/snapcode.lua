--[[ local codesnap <const> = require("codesnap") ]]
require("codesnap").setup({
    mac_window_bar = true,
    title = "fffff",
    code_font_family = "",
    watermark_font_family = "Pacifico",
    watermark = "@d7g.x",
    bg_theme = "dusk",

    -- bg_padding = 0, --remove bg if set to 0
    breadcrumbs_separator = "/",
    has_breadcrumbs = false,
    has_line_number = true,
    show_workspace = false,
    min_width = 0,
    -- bg_x_padding = 122,
    -- bg_y_padding = 82,
    -- save_path = (os.getenv("HOME") .. "/Deveolper"),
})
