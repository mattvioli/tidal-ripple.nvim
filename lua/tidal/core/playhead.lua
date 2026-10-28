local config = require("tidal.config")

local M = {}

local markers = {}
local flash_timers = {}

local FALLBACK_FLASH_MS = 200
local MIN_FLASH_MS = 80
local MAX_FLASH_MS = 500

function M.enqueue(bufnr, start_line, end_line, orbit)
  local ns = config.playhead_ns
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local line = math.min(start_line, line_count - 1)

  for _, m in ipairs(markers) do
    if m.bufnr == bufnr and m.line == line then
      return
    end
  end

  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
    sign_text = "▶",
    sign_hl_group = "TidalRipplePlayhead",
    priority = vim.hl.priorities.user + 10,
    strict = false,
  })
  table.insert(markers, { id = id, bufnr = bufnr, line = line, orbit = orbit })
end

local function update_marker(m, hl_group)
  if not m or not vim.api.nvim_buf_is_valid(m.bufnr) then
    return
  end
  pcall(vim.api.nvim_buf_del_extmark, m.bufnr, config.playhead_ns, m.id)
  local id = vim.api.nvim_buf_set_extmark(m.bufnr, config.playhead_ns, m.line, 0, {
    sign_text = "▶",
    sign_hl_group = hl_group,
    priority = vim.hl.priorities.user + 10,
    strict = false,
  })
  if id then
    m.id = id
  end
end

local function reset_flash(m)
  if flash_timers[m.id] then
    flash_timers[m.id]:stop()
    flash_timers[m.id]:close()
    flash_timers[m.id] = nil
  end
  update_marker(m, "TidalRipplePlayhead")
end

local function apply_flash(m, parsed)
  update_marker(m, "TidalRippleFlash")
  if flash_timers[m.id] then
    flash_timers[m.id]:stop()
    flash_timers[m.id]:close()
  end

  local delta = parsed and parsed.delta
  local duration = FALLBACK_FLASH_MS
  if delta and delta > 0 then
    duration = math.floor(delta * 1000)
    duration = math.max(MIN_FLASH_MS, math.min(duration, MAX_FLASH_MS))
  end

  local timer = vim.uv.new_timer()
  flash_timers[m.id] = timer
  timer:start(
    duration,
    0,
    vim.schedule_wrap(function()
      if flash_timers[m.id] == timer then
        flash_timers[m.id] = nil
      end
      update_marker(m, "TidalRipplePlayhead")
    end)
  )
end

local function latest_marker_for_orbit(orbit)
  for i = #markers, 1, -1 do
    local m = markers[i]
    if m.orbit == orbit then
      return m
    end
  end
end

function M.on_cycle(parsed)
  if not parsed or parsed.orbit == nil then
    return
  end
  local m = latest_marker_for_orbit(parsed.orbit)
  if m then
    apply_flash(m, parsed)
  end
end

function M.clear(orbit)
  if orbit then
    for i = #markers, 1, -1 do
      local marker = markers[i]
      if marker.orbit == orbit then
        reset_flash(marker)
        if vim.api.nvim_buf_is_valid(marker.bufnr) then
          pcall(vim.api.nvim_buf_del_extmark, marker.bufnr, config.playhead_ns, marker.id)
        end
        table.remove(markers, i)
      end
    end
    return
  end

  for _, marker in ipairs(markers) do
    reset_flash(marker)
    if vim.api.nvim_buf_is_valid(marker.bufnr) then
      pcall(vim.api.nvim_buf_del_extmark, marker.bufnr, config.playhead_ns, marker.id)
    end
  end
  markers = {}
end

function M.reset()
  M.clear()
end

return M
