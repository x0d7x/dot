local pack = require("core.pack")

vim.g.fff = {
	prompt_vim_mode = false,
	lazy_sync = true,
	debug = {
		enabled = true,
		show_scores = true,
	},
	keymaps = {
		close = "q",
		move_up = "<C-k>",
		move_down = "<C-j>",
	},
	layout = {
		prompt_position = "top",
	},
}

pack.add({ "https://github.com/dmtrKovalenko/fff.nvim" })

vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "fff.nvim" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd("fff.nvim")
			end
			require("fff.download").download_or_build_binary()
		end
	end,
})

vim.keymap.set("n", "fm", function()
	require("fff").live_grep({ query = vim.fn.expand("<cword>") })
end, { desc = "Search current word" })

vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		local plugin_dir = vim.fn.stdpath("data") .. "/site/pack/core/opt/fff.nvim"
		local binary = plugin_dir .. "/target/release/libfff_nvim.so"
		if vim.fn.filereadable(binary) ~= 1 then
			require("fff.download").download_or_build_binary()
		end
	end,
})
