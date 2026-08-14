local pack = require("core.pack")

pack.add({ "https://github.com/williamboman/mason.nvim" })

local opts = {
	ensure_installed = {
		"lua-language-server",
		"gopls",
		"vtsls",
		"tsgo",
		"tailwindcss-language-server",
		"html-lsp",
		"css-lsp",
		"astro-language-server",
		"typescript-language-server",
		"stylua",
		"goimports",
		"prettier",
		"golangci-lint",
		"eslint_d",
		"shfmt",
		"shellcheck",
	},
}

require("mason").setup(opts)

local mr = require("mason-registry")
local function ensure_installed()
	for _, tool in ipairs(opts.ensure_installed) do
		if mr.has_package(tool) then
			local p = mr.get_package(tool)
			if not p:is_installed() then
				vim.notify("Mason: Installing " .. tool .. "...", vim.log.levels.INFO)
				p:install():once("closed", function()
					if p:is_installed() then
						vim.notify("Mason: Successfully installed " .. tool, vim.log.levels.INFO)
					else
						vim.notify("Mason: Failed to install " .. tool, vim.log.levels.ERROR)
					end
				end)
			end
		else
			vim.notify("Mason: Package '" .. tool .. "' not found", vim.log.levels.WARN)
		end
	end
end

if mr.refresh then
	mr.refresh(ensure_installed)
else
	ensure_installed()
end
