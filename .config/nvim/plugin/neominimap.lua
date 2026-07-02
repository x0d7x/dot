vim.pack.add({
	{ src = "https://github.com/Isrothy/neominimap.nvim" },
})

-- The following options are recommended when layout == "float"
-- vim.opt.wrap = false
-- vim.opt.sidescrolloff = 36 -- Set a large value

--- Put your configuration here
---@type Neominimap.UserConfig
vim.g.neominimap = {
	auto_enable = true,
}
