local pack = require("core.pack")

pack.add({
	"https://github.com/echasnovski/mini.nvim",
})

require("mini.ai").setup({ n_lines = 500 })

require("mini.surround").setup({
	mappings = {
		add = "gsa",
		delete = "gsd",
		find = "gsf",
		find_left = "gsF",
		highlight = "gsh",
		replace = "gsr",
		update_n_lines = "gsn",
	},
})

require("mini.pairs").setup()

---- mini notify ----
require("mini.notify").setup({
	-- only show messages
	content = {
		format = function(notif)
			return notif.msg
		end,
	},
})

require("mini.files").setup({
	mappings = {
		synchronize = "s",
	},
	-- windows = {
	-- 	preview = true,
	-- 	width_preview = 50,
	-- 	width_focus = 50,
	-- 	width_nofocus = 0,
	-- },
})
