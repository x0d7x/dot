-- Native floating terminal
-- Toggle a floating terminal window using pure Neovim API (no plugins)

local M = {}

local term_buf = nil
local term_win = nil

local function calculate_win_dimensions()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  return width, height, col, row
end

local function setup_buffer(buf)
  -- Must be called while buf is current, so use nvim_buf_call
  vim.api.nvim_buf_call(buf, function()
    vim.fn.termopen(vim.o.shell, vim.empty_dict())
  end)

  -- Keymaps
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = buf, desc = "Exit terminal mode" })
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
  end, { buffer = buf, desc = "Hide terminal" })

  -- Reset state when terminal process exits
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = buf,
    once = true,
    callback = function()
      term_buf = nil
      term_win = nil
    end,
  })
end

function M.toggle()
  -- If window exists and is valid, close it (hide)
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
    return
  end

  local width, height, col, row = calculate_win_dimensions()

  -- Create or reuse buffer
  if not (term_buf and vim.api.nvim_buf_is_valid(term_buf)) then
    term_buf = vim.api.nvim_create_buf(false, false)
  end

  -- Start terminal if not already running
  if not vim.bo[term_buf].channel or vim.bo[term_buf].channel == 0 then
    setup_buffer(term_buf)
  end

  term_win = vim.api.nvim_open_win(term_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
  })

  vim.cmd("startinsert!")
end

function M.open()
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_current_win(term_win)
    return
  end
  M.toggle()
end

function M.close()
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
  end
end

return M
