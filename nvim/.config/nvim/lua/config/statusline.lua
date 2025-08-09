-- ========== Statusline Utilities ========== --

local function diagnostic_status()
	local icons = { Error = "", Warn = "", Info = "", Hint = "" }
	local count = { Error = 0, Warn = 0, Info = 0, Hint = 0 }

	for _, d in ipairs(vim.diagnostic.get(0)) do
		for level in pairs(count) do
			if d.severity == vim.diagnostic.severity[level:upper()] then
				count[level] = count[level] + 1
			end
		end
	end

	local parts = {}
	for level, n in pairs(count) do
		if n > 0 then
			table.insert(parts, icons[level] .. n)
		end
	end

	if #parts == 0 then
		return ""
	end
	return " " .. table.concat(parts, " ") .. " "
end

_G.DiagnosticStatus = diagnostic_status

function BufferStatus()
	local current_buf = vim.api.nvim_get_current_buf()
	local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
	local total = #listed_buffers
	local current_index = 0

	for i, buf in ipairs(listed_buffers) do
		if buf.bufnr == current_buf then
			current_index = i
			break
		end
	end

	return string.format(" [%d/%d] ", current_index, total)
end

function Lsp_status()
	local names = {}
	for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if not client.is_stopped or not client:is_stopped() then
			table.insert(names, client.name)
		end
	end

	if #names == 0 then
		return ""
	end

	return (" [󱒄 %s]"):format(table.concat(names, ","))
end

-- function Formatter_status()
-- 	local ok, conform = pcall(require, "conform")
-- 	if not ok then
-- 		return ""
-- 	end
-- 	local list = conform.list_formatters_to_run(0)
-- 	if #list == 0 then
-- 		return ""
-- 	end
-- 	return "󰉿 " .. table.concat(
-- 		vim.tbl_map(function(f)
-- 			return f.name
-- 		end, list),
-- 		","
-- 	)
-- end

_G.git_statusline = function()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return ""
	end

	local parts = { " " .. git_info.head }

	if (git_info.added or 0) > 0 then
		table.insert(parts, " " .. git_info.added)
	end
	if (git_info.changed or 0) > 0 then
		table.insert(parts, " " .. git_info.changed)
	end
	if (git_info.removed or 0) > 0 then
		table.insert(parts, " " .. git_info.removed)
	end

	return "[" .. table.concat(parts, " ") .. "]"
end

local function filepath()
	-- Modify the given file path with the given modifiers
	local fpath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.:h")

	if fpath == "" or fpath == "." then
		return ""
	end

	return string.format("%%<%s/", fpath)
	-- `%%` -> `%`.
	-- `%s` -> value of `fpath`.
	-- The result is `%<fpath/`.
	-- `%<` tells where to truncate when there is not enough space.
end

-- function Linter_status()
-- 	local ok, lint = pcall(require, "lint")
-- 	if not ok then
-- 		return ""
-- 	end
-- 	local linters = lint.linters_by_ft[vim.bo.filetype] or {}
-- 	if #linters == 0 then
-- 		return ""
-- 	end
-- 	return "󰁨 " .. table.concat(linters, ",")
-- end

-- register the key to store the last key pressed
vim.on_key(function(k)
	vim.g.last_key = k
end, vim.api.nvim_create_namespace("last_key_ns"))

vim.opt.statusline = table.concat({
	"[",
	filepath(),
	"%t] ", -- filename
	"%{v:lua.git_statusline()}",
	"%m", -- modified
	-- "%y", -- filetype
	"%r", -- readonly
	"%=", -- right align
	-- "%{v:lua.GitsignsStatus()}",
	-- "%{mode()} ",  -- mode short (n,i,v)
	"%{v:lua.DiagnosticStatus()}",
	"%{exists('g:last_key') ? (' ' .. g:last_key .. ' ') : ''}",
	"%{v:lua.BufferStatus()}", -- buffer
	"%{v:lua.Lsp_status()}", -- lsp
	-- "%{v:lua.Linter_status()}",  -- linter
	-- "%{v:lua.Formatter_status()}",  -- formatter
	-- " %l:%c",  -- line and column
	-- " %p%%", -- percentage
})
