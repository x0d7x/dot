return {
	{ "L3MON4D3/LuaSnip", keys = {} },
	{
		"saghen/blink.cmp",
		dependencies = {
			"rafamadriz/friendly-snippets",
		},
		event = "InsertEnter",
		version = "*",
		config = function()
			vim.cmd("highlight NormalFloat guibg=NONE blend=0")
			vim.cmd("highlight FloatBorder guibg=NONE blend=0")
			vim.cmd("highlight Pmenu guibg=NONE blend=0")
			vim.cmd("highlight PmenuSel guibg=NONE blend=0")
			require("blink.cmp").setup({
				snippets = { preset = "luasnip" },
				signature = { enabled = true },
				appearance = {
					use_nvim_cmp_as_default = false,
					nerd_font_variant = "mono",
				},
				sources = {
					-- per_filetype = {
					--     codecompanion = { "codecompanion" },
					-- },
					default = { "lsp", "path", "snippets", "buffer" },
				},
				keymap = { preset = "enter" },
				cmdline = {
					enabled = false,
					completion = {
						documentation = {
							auto_show = true,
							auto_show_delay_ms = 200,
						},
						menu = {
							auto_show = false,
							-- auto_show_delay_ms = 500,
						},
					},
					keymap = {
						["<CR>"] = { "accept_and_enter", "fallback" },
					},
				},
				completion = {
					accept = { auto_brackets = { enabled = false } },
					menu = {
						auto_show = true,
						border = nil,
						winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder,Pmenu:Pmenu",
						scrolloff = 1,
						scrollbar = false,
						draw = {
							columns = {
								{ "kind_icon" },
								{ "label", "label_description", gap = 1 },
								{ "kind" },
								{ "source_name" },
							},
						},
					},
					documentation = {
						window = {
							border = nil,
							scrollbar = false,
							winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
						},
						auto_show = true,
						auto_show_delay_ms = 500,
					},
				},
			})

			require("luasnip.loaders.from_vscode").lazy_load()
		end,
	},
}
