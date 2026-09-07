local config = require("tidal.config")

local M = {}

local highlights = {}
local flash_timers = {}

local HIGHLIGHT_NS = nil

local DEFAULT_HL = "TidalRippleEvent"
local DEFAULT_FADE_MS = 400

local function setup_namespace()
  if not HIGHLIGHT_NS then
    HIGHLIGHT_NS = vim.api.nvim_create_namespace("TidalRippleEvent")
  end
  return HIGHLIGHT_NS
end

local function get_highlight_group()
  return config.options.event_highlight
      and config.options.event_highlight.highlight
      and config.options.event_highlight.highlight.link
    or DEFAULT_HL
end

local function get_fade_ms()
  return config.options.event_highlight and config.options.event_highlight.fade_ms or DEFAULT_FADE_MS
end

local function clear_flash(key)
  if flash_timers[key] then
    flash_timers[key]:stop()
    flash_timers[key]:close()
    flash_timers[key] = nil
  end
end

local function apply_flash(bufnr, line, key, duration)
  local ns = setup_namespace()
  local hl_group = get_highlight_group()

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local row = math.min(line, line_count - 1)
  local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line_text or #line_text == 0 then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    end_line = row + 1,
    hl_group = hl_group,
    priority = vim.hl.priorities.user + 5,
  })

  clear_flash(key)

  local timer = vim.uv.new_timer()
  flash_timers[key] = timer
  timer:start(
    duration,
    0,
    vim.schedule_wrap(function()
      if flash_timers[key] == timer then
        flash_timers[key] = nil
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
      end
    end)
  )
end

function M.on_event(parsed)
  if not parsed or not parsed.orbit then
    return
  end

  local orbit = parsed.orbit
  for _, h in ipairs(highlights) do
    if h.orbit == orbit and vim.api.nvim_buf_is_valid(h.bufnr) then
      local delta = parsed.delta
      local duration = get_fade_ms()
      if delta and delta > 0 then
        duration = math.floor(delta * 1000)
      end
      apply_flash(h.bufnr, h.line, "orbit_" .. orbit, duration)
      return
    end
  end
end

function M.track(bufnr, line, orbit)
  for _, h in ipairs(highlights) do
    if h.bufnr == bufnr and h.line == line and h.orbit == orbit then
      return
    end
  end
  table.insert(highlights, {
    bufnr = bufnr,
    line = line,
    orbit = orbit,
  })
end

function M.clear(orbit)
  if orbit then
    local ns = setup_namespace()
    for i = #highlights, 1, -1 do
      local h = highlights[i]
      if h.orbit == orbit then
        if vim.api.nvim_buf_is_valid(h.bufnr) then
          vim.api.nvim_buf_clear_namespace(h.bufnr, ns, h.line, h.line + 1)
        end
        table.remove(highlights, i)
      end
    end
    clear_flash("orbit_" .. orbit)
  else
    local ns = setup_namespace()
    for _, h in ipairs(highlights) do
      if vim.api.nvim_buf_is_valid(h.bufnr) then
        vim.api.nvim_buf_clear_namespace(h.bufnr, ns, h.line, h.line + 1)
      end
    end
    highlights = {}
    for key in pairs(flash_timers) do
      clear_flash(key)
    end
  end
end

function M.stop()
  M.clear()
end

return M
