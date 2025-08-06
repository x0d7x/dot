return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		dashboard = {
			enabled = true,
			preset = {
				header = [[

  ██████╗  █████╗ ██╗     ███████╗███████╗████████╗██╗███╗   ██╗███████╗
  ██╔══██╗██╔══██╗██║     ██╔════╝██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝
██████╔╝███████║██║     █████╗  ███████╗   ██║   ██║██╔██╗ ██║█████╗
██╔═══╝ ██╔══██║██║     ██╔══╝  ╚════██║   ██║   ██║██║╚██╗██║██╔══╝
  ██║     ██║  ██║███████╗███████╗███████║   ██║   ██║██║ ╚████║███████╗
  ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝

❤️🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤
❤️❤️🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤
❤️❤️❤️🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤🖤
❤️❤️❤️❤️🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍
❤️❤️❤️❤️❤️🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍
❤️❤️❤️❤️🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍🤍
❤️❤️❤️💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚
❤️❤️💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚
❤️💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚💚
]],
			},
			sections = {
				{ section = "header", gap = 2 },
				{ section = "startup" },
				{ section = "keys", gap = 1, padding = { 2, 2 } },
				{ icon = " ", title = "Recent Files", section = "recent_files", indent = 10, padding = { 1, 1 } },
				{ icon = " ", title = "Projects", section = "projects", indent = 10, padding = 2 },
			},
		},
		-- explorer = { enabled = true },
		bigfile = { enabled = true },
		indent = { enabled = false },
		input = { enabled = false },
		notifier = {
			enabled = true,
			timeout = 3000,
		},
		quickfile = { enabled = true },
		notify = { enabled = false },
		picker = {
			enabled = true,
			matcher = {
				frecency = true,
			},
		},
		scope = { enabled = true },
		scroll = { enabled = true },
		scratch = { enabled = true },
		words = { enabled = true },
		toggle = { enabled = true },
		image = { enabled = true },
		zen = { enabled = true },
		lazygit = { enabld = false },
		animate = { enabled = false },
		-- statuscolumn = { enabled = true },
	},
	init = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- Setup some globals for debugging (lazy-loaded)
				_G.dd = function(...)
					Snacks.debug.inspect(...)
				end
				_G.bt = function()
					Snacks.debug.backtrace()
				end
				vim.print = _G.dd -- Override print to use snacks for `:=` command

				-- Create some toggle mappings
				Snacks.toggle.scroll():map("<leader>uS")
				Snacks.toggle.animate():map("<leader>ua")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
				Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
				Snacks.toggle.diagnostics():map("<leader>ud")
				Snacks.toggle.line_number():map("<leader>ul")
				Snacks.toggle
					.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
					:map("<leader>uc")
				Snacks.toggle.treesitter():map("<leader>uT")
				Snacks.toggle
					.option("background", { off = "light", on = "dark", name = "Dark Background" })
					:map("<leader>ub")
				Snacks.toggle.inlay_hints():map("<leader>uh")
				Snacks.toggle.indent():map("<leader>ug")
				-- Toggle the profiler
				Snacks.toggle.profiler():map("<leader>pp")
				-- Toggle the profiler highlights
				Snacks.toggle.profiler_highlights():map("<leader>ph")
				Snacks.toggle.zen():map("<leader>uz")
				Snacks.toggle.zoom():map("<leader>wm")
			end,
		})
	end,
}
