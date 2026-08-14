local pack = require("core.pack")

pack.add({
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/martindur/zdiff.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/NeogitOrg/neogit",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/folke/snacks.nvim",
	"https://github.com/justinmk/guh.nvim",
})

require("gitsigns").setup({
	signs = {
		add = { text = "" },
		change = { text = "|" },
		delete = { text = "" },
		topdelete = { text = "󰆴" },
		changedelete = { text = "󰍵" },
		untracked = { text = "" },
	},
	signs_staged = {
		add = { text = "" },
		change = { text = "" },
		delete = { text = "" },
		topdelete = { text = "" },
		changedelete = { text = "" },
		untracked = { text = "" },
	},
	-- current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
	current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
		delay = 100, -- Delay in milliseconds before blame shows
	},
	-- <author>, <author_time:%Y-%m-%d> - <summary>
	current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> ",
})

require("neogit").setup({
	cmd = "Neogit",
	graph_style = "kitty",
})
vim.api.nvim_create_autocmd("FileType", {
	pattern = "NeogitStatus",
	callback = function(args)
		vim.keymap.set("n", "D", function()
			require("zdiff").open()
		end, {
			buffer = args.buf,
			desc = "Open zdiff",
		})
	end,
})
