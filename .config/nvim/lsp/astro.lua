---@brief
---
--- https://github.com/withastro/language-tools/tree/main/packages/language-server
---
--- `astro-ls` can be installed via `npm`:
--- ```sh
--- npm install -g @astrojs/language-server
--- ```

local function get_tsdk_path()
	local tsdk = vim.fn.stdpath("data") .. "/mason/packages/vtsls/node_modules/typescript/lib"
	if vim.fn.isdirectory(tsdk) == 1 then
		return tsdk
	else
		return nil
	end
end

return {
	cmd = { "astro-ls", "--stdio" },
	filetypes = { "astro" },
	root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
	init_options = {
		typescript = {
			tsdk = get_tsdk_path(),
		},
	},
}
