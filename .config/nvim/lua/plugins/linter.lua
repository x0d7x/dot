return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufWritePost", "InsertLeave" },
	config = function()
		local lint = require("lint")

		-- Custom linter configurations (optional args/conditions)
		-- lint.linters.astro = {
		--   cmd = "eslint_d",
		--   stdin = true,
		--   args = { "--stdin", "--stdin-filename", function() return vim.api.nvim_buf_get_name(0) end, "-f", "json" },
		--   stream = "stdout",
		--   ignore_exitcode = true,
		--   parser = require("lint.parser.eslint")(),
		--   condition = function(ctx)
		--     return vim.fs.find({ ".eslintrc.cjs", ".eslintrc.js", ".eslintrc.json" }, { upward = true, path = ctx.dirname })[1]
		--   end,
		-- }

		-- Set filetype to linter mapping
		lint.linters_by_ft = {
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			astro = { "eslint_d" },
			-- lua = { "luacheck" },
			go = { "golangcilint" },
			python = { "ruff" },
			markdown = { "markdownlint-cli2" },
			html = {},
			css = {},
			tailwindcss = {},
			dockerfile = {},
			sql = {},
			terraform = {},
			json = {},
			yaml = {},
		}
		lint.linters.eslint_d = {
			cmd = "eslint_d",
			stdin = true,
			args = {
				"--format",
				"json",
				"--stdin",
				"--stdin-filename",
				function()
					return vim.api.nvim_buf_get_name(0)
				end,
			},
			stream = "stdout",
			ignore_exitcode = true,
			parser = require("lint.parser").from_errorformat("%f:%l:%c: %m", {
				source = "eslint_d",
				format = "json",
				-- if you have custom parsing logic you can use on_output instead of errorformat
			}),
		}
		-- Debounce function
		local function debounce(ms, fn)
			local timer = vim.uv.new_timer()
			return function(...)
				local argv = { ... }
				timer:start(ms, 0, function()
					timer:stop()
					vim.schedule_wrap(fn)(unpack(argv))
				end)
			end
		end

		-- Custom lint function with fallback and global linter support
		local function do_lint()
			local names = lint._resolve_linter_by_ft(vim.bo.filetype)
			names = vim.list_extend({}, names)
			vim.list_extend(names, lint.linters_by_ft._ or {})
			vim.list_extend(names, lint.linters_by_ft["*"] or {})

			local ctx = { filename = vim.api.nvim_buf_get_name(0) }
			ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")

			names = vim.tbl_filter(function(name)
				local linter = lint.linters[name]
				if not linter then
					vim.notify("Linter not found: " .. name, vim.log.levels.WARN, { title = "nvim-lint" })
				end
				return linter and not (linter.condition and not linter.condition(ctx))
			end, names)

			if #names > 0 then
				lint.try_lint(names)
			end
		end

		-- Autocommand to trigger lint on specific events
		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufReadPost" }, {
			group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
			callback = debounce(100, do_lint),
		})
	end,
}
