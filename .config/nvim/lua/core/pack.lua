local M = {}

local pack_root = vim.fn.stdpath("data") .. "/site/pack/core/opt"

local build_hooks = {
	["nvim-treesitter"] = ":TSUpdate",
	["mason.nvim"] = ":MasonUpdate",
	["blink.cmp"] = "cargo build --release",
	["fff.nvim"] = "cargo build --release",
}

local function run_shell_build(name, cmd)
	local cwd = pack_root .. "/" .. name
	if vim.fn.isdirectory(cwd) == 0 then
		vim.notify("Pack build path missing for " .. name, vim.log.levels.WARN)
		return
	end

	local result = vim.system({ "sh", "-c", cmd }, { cwd = cwd, text = true }):wait()
	if result.code ~= 0 then
		local stderr = result.stderr and result.stderr:gsub("%s+$", "") or ""
		vim.notify("Pack build failed for " .. name .. ": " .. stderr, vim.log.levels.ERROR)
	end
end

local function run_build(name, build)
	if type(build) == "function" then
		build()
		return
	end

	if type(build) == "string" then
		if build:sub(1, 1) == ":" then
			vim.cmd(build)
		else
			run_shell_build(name, build)
		end
	end
end

vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local kind = ev.data.kind
		if kind ~= "install" and kind ~= "update" then
			return
		end

		local name = ev.data.spec and ev.data.spec.name
		local build = name and build_hooks[name] or nil
		if not build then
			return
		end

		if not ev.data.active then
			vim.cmd.packadd(name)
		end
		run_build(name, build)
	end,
})

vim.schedule(function()
	vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
end)

function M.add(specs, opts)
	opts = opts or {}
	if opts.confirm == nil then
		opts.confirm = false
	end
	if opts.load == nil then
		opts.load = true
	end
	vim.pack.add(specs, opts)
end

return M
