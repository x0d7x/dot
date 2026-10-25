---@brief
---
--- https://github.com/withastro/astro/tree/main/packages/language-tools/language-server
---
--- `astro-ls` can be installed via `npm`:
--- ```sh
--- npm install -g @astrojs/language-server
--- ```

local function get_tsdk_path(root_dir)
	-- 1) Prefer workspace-local TypeScript
	if root_dir then
		local local_ts = vim.fs.joinpath(root_dir, "node_modules", "typescript", "lib")
		if vim.fn.isdirectory(local_ts) == 1 then
			return local_ts
		end
	end

	-- 2) Fall back to global npm TypeScript
	local npm_root = vim.fn.systemlist("npm root -g")
	if vim.v.shell_error == 0 and npm_root[1] then
		local global_ts = npm_root[1] .. "/typescript/lib"
		if vim.fn.isdirectory(global_ts) == 1 then
			return global_ts
		end
	end

	-- 3) Optional Mason fallback if you use vtsls there
	local mason_ts = vim.fn.stdpath("data") .. "/mason/packages/vtsls/node_modules/typescript/lib"
	if vim.fn.isdirectory(mason_ts) == 1 then
		return mason_ts
	end

	return nil
end

---@type vim.lsp.Config
return {
	cmd = function(dispatchers, config)
		local cmd = "astro-ls"
		if (config or {}).root_dir then
			local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules", ".bin", cmd)
			if vim.fn.executable(local_cmd) == 1 then
				cmd = local_cmd
			end
		end
		return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers)
	end,
	filetypes = { "astro" },
	root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
	init_options = {
		typescript = {},
	},
	before_init = function(_, config)
		config.init_options = config.init_options or {}
		config.init_options.typescript = config.init_options.typescript or {}

		if not config.init_options.typescript.tsdk then
			config.init_options.typescript.tsdk = get_tsdk_path(config.root_dir)
		end
	end,
}
