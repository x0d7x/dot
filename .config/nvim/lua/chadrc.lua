-- This file needs to have same structure as nvconfig.lua
--https://github.com/NvChad/ui/blob/v2.5/lua/nvconfig.lua
-- -@type ChadrcConfig
local M = {}
M.base46 = {
    theme = "gruvchad",
    transparency = true,
}

M.ui = {
    statusline = {
        theme = "minimal", -- default/vscode/vscode_colored/minimal
        separator_style = "round",
        -- default/round/block/arrow separators work only for default statusline theme
        -- round and block will work for minimal theme only
    },
    cmp = {
        icons = true,
        lspkind_text = true,
        style = "default", -- default/flat_light/flat_dark/atom/atom_colored
        -- icons_left = true,
    },
    -- hl_override = {
    -- Comment = { italic = true },
    -- 	["@comment"] = { italic = true },
    -- },
}

M.lsp = { signature = false }

return M
