local pack = require("core.pack")

pack.add({
	"https://github.com/vague2k/vague.nvim",
	"https://github.com/Aejkatappaja/sora",
	"https://github.com/oskarnurm/koda.nvim",
	"https://github.com/nendix/zen.nvim",
	"https://github.com/Koalhack/darcubox-nvim",
	"https://github.com/rebelot/kanagawa.nvim",
	{ src = "https://gitlab.com/motaz-shokry/gruvbox.nvim.git", name = "gruvbox" },
	"https://github.com/darianmorat/gruvdark.nvim",
	"https://github.com/connormxfadden/petrolnoir.nvim",
	"https://github.com/mcauley-penney/techbase.nvim",
})

require("vague").setup({
	transparent = true,
	colors = {
		visual = "#cb945b",
		comment = "#666666",
	},
})
-- vim.cmd.colorscheme("vague")

require("sora").setup({ transparent = true })

-- vim.cmd("colorscheme sora")

require("koda").setup({
	transparent = true,
	on_highlights = function(hl)
		hl.Comment = { fg = "#666666", italic = true }
	end,
})
-- vim.cmd("colorscheme koda-dark")

require("zen").setup({ transparent = false })

vim.cmd("colorscheme zen")

require("darcubox").setup({
	options = {
		transparent = true,
		styles = {
			comments = { italic = true },
			functions = { bold = true },
			keywords = { italic = true },
			types = { italic = true, bold = true },
		},
	},
})

require("kanagawa").setup({
	transparent = true,
	terminalColors = true,
	theme = "dragon",
	background = {
		dark = "dragon",
	},
})

require("gruvbox").setup({
	variant = "hard",
	styles = {
		transparency = true,
	},
})
-- vim.cmd.colorscheme("gruvbox")

require("gruvdark").setup({ transparent = false })

require("techbase").setup({ transparent = true })
-- vim.cmd.colorscheme("techbase")

require("petrolnoir").setup({ transparent = true })
-- vim.api.nvim_set_hl(0, "CursorLine", {
-- fg = "#ffffff",
-- bg = "#CC7653",
-- bold = true,
-- })
-- vim.api.nvim_set_hl(0, "LineNr", { fg = "#666666", bg = "NONE" })
-- vim.api.nvim_set_hl(0, "Comment", { fg = "#666666", italic = true })
-- vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#CC7653", bold = true, bg = "NONE" })
