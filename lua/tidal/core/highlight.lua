local config = require("tidal.config")

local M = {}

local ns = config.namespace
local hl_opts = config.options.selection_highlight
local higroup = "TidalRippleSent"

vim.api.nvim_set_hl(0, higroup, hl_opts.highlight)

if not vim.hl or not vim.hl.priorities or not vim.hl.priorities.user then
  vim.hl = vim.hl or {}
  vim.hl.priorities = vim.hl.priorities or {}
  vim.hl.priorities.user = vim.hl.priorities.user or 101
end

function M.apply_highlight(start, finish)
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.hl and vim.hl.range then
    local ok = pcall(vim.hl.range, bufnr, ns, higroup, start, finish, {
      regtype = "v",
      inclusive = true,
      priority = vim.hl.priorities.user,
      timeout = hl_opts.timeout,
    })
    if ok then
      return
    end
  end

  -- Fallback: use buffer highlights like event_highlight does
  local timeout = hl_opts.timeout or 150
  local start_row = start[1]
  local start_col = start[2] or 0
  local finish_row = finish[1]
  local finish_col = finish[2] or start_col
  if finish_row < start_row then
    start_row, finish_row = finish_row, start_row
  end
  if finish_row == start_row and finish_col < start_col then
    start_col, finish_col = finish_col, start_col
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, start_row, finish_row + 1)
  if finish_row == start_row then
    vim.api.nvim_buf_add_highlight(bufnr, ns, higroup, start_row, start_col, finish_col + 1)
  else
    vim.api.nvim_buf_add_highlight(bufnr, ns, higroup, start_row, start_col, -1)
    for row = start_row + 1, finish_row - 1 do
      vim.api.nvim_buf_add_highlight(bufnr, ns, higroup, row, 0, -1)
    end
    vim.api.nvim_buf_add_highlight(bufnr, ns, higroup, finish_row, 0, finish_col + 1)
  end
  local timer = vim.uv.new_timer()
  timer:start(
    timeout,
    0,
    vim.schedule_wrap(function()
      timer:stop()
      timer:close()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns, start_row, finish_row + 1)
      end
    end)
  )
end

function M.clear_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

return M
