-- local lazierPath = vim.fn.stdpath("data") .. "/lazier/lazier.nvim"
-- if not (vim.uv or vim.loop).fs_stat(lazierPath) then
-- 	local repo = "https://github.com/jake-stewart/lazier.nvim.git"
-- 	local out = vim.fn.system({
-- 		"git",
-- 		"clone",
-- 		"--branch=stable-v2",
-- 		repo,
-- 		lazierPath,
-- 	})
-- 	if vim.v.shell_error ~= 0 then
-- 		vim.api.nvim_echo({ {
-- 			"Failed to clone lazier.nvim:\n" .. out,
-- 			"Error",
-- 		} }, true, {})
-- 	end
-- end
-- vim.opt.runtimepath:prepend(lazierPath)
--
-- require("lazier").setup("plugins", {
-- 	lazier = {
-- 		before = function()
-- 			-- function to run before the ui renders.
-- 			-- it is faster to require parts of your config here
-- 			-- since at this point they will be bundled and bytecode compiled.
-- 			-- eg: require("options")
-- 		end,
--
-- 		after = function()
-- 			-- function to run after the ui renders.
-- 			-- eg: require("mappings")
-- 		end,
--
-- 		start_lazily = function()
-- 			-- function which returns whether lazy.nvim
-- 			-- should start delayed or not.
-- 			local nonLazyLoadableExtensions = {
-- 				zip = true,
-- 				tar = true,
-- 				gz = true,
-- 			}
-- 			local fname = vim.fn.expand("%")
-- 			return fname == ""
-- 				or vim.fn.isdirectory(fname) == 0
-- 					and not nonLazyLoadableExtensions[vim.fn.fnamemodify(fname, ":e")]
-- 		end,
--
-- 		-- whether plugins should be included in the bytecode
-- 		-- compiled bundle. this will make your startup slower.
-- 		bundle_plugins = false,
--
-- 		-- whether to automatically generate lazy loading config
-- 		-- by identifying the mappings set when the plugin loads
-- 		generate_lazy_mappings = true,
--
-- 		-- automatically rebundle and compile nvim config when it changes
-- 		-- if set to false then you will need to :LazierClear manually
-- 		detect_changes = true,
-- 	},
--
-- 	-- your usual lazy.nvim config goes here
-- 	spec = {
-- 		-- import your plugins
-- 		{ import = "plugins" },
-- 		--
-- 	},
-- 	defaults = {
-- 		-- smmflkmflm
-- 		-- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
-- 		lazy = false,
-- 	},
-- 	-- Configure any other settings here. See the documentation for more details.
-- 	-- colorscheme that will be used when installing plugins.
-- 	install = { colorscheme = { "solarized" } },
-- 	ui = {
-- 		border = "rounded",
-- 		backdrop = 100,
-- 		title = "dullx Lazy",
-- 	},
-- 	-- automatically check for plugin updates
-- 	checker = {
-- 		enabled = true,
-- 		notify = true,
-- 	},
-- 	performance = {
-- 		rtp = {
-- 			disabled_plugins = {
-- 				"gzip",
-- 				"tarPlugin",
-- 				"tohtml",
-- 				"tutor",
-- 				"zipPlugin",
-- 			},
-- 		},
-- 	},
-- 	-- ...
-- })
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " " -- Set <Leader> key to Space
vim.g.maplocalleader = " " -- Set <LocalLeader> key to Space

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins" },
		--
	},
	defaults = {
		-- smmflkmflm
		-- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
		lazy = false,
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "solarized" } },
	ui = {
		border = "rounded",
		backdrop = 100,
		title = "dullx Lazy",
	},
	-- automatically check for plugin updates
	checker = {
		enabled = true,
		notify = true,
	},
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
