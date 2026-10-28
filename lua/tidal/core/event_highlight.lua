local config = require("tidal.config")

local M = {}
local tracks = {}
local flash_timers = {}
local ns = nil
local default_hl = "TidalRippleEvent"
local default_fade_ms = 400

local function get_ns()
  if ns == nil then
    ns = vim.api.nvim_create_namespace("TidalRippleEvent")
  end
  return ns
end

local function get_hl()
  local hl = config.options.event_highlight
      and config.options.event_highlight.highlight
      and config.options.event_highlight.highlight.link
    or default_hl
  pcall(vim.api.nvim_set_hl, 0, hl, { bg = "#ff0000", fg = "#ffff00", bold = true, underline = true, nocombine = true })
  return hl
end

local function get_fade()
  return config.options.event_highlight and config.options.event_highlight.fade_ms or default_fade_ms
end

local function clear_flash(key)
  if flash_timers[key] ~= nil then
    if type(flash_timers[key]) == "table" and flash_timers[key].stop then
      pcall(function()
        flash_timers[key]:stop()
        flash_timers[key]:close()
      end)
    end
    if type(flash_timers[key]) == "number" then
      pcall(vim.fn.matchdelete, flash_timers[key])
    end
    flash_timers[key] = nil
  end
end

if not vim.hl or not vim.hl.priorities or not vim.hl.priorities.user then
  vim.hl = vim.hl or {}
  vim.hl.priorities = vim.hl.priorities or {}
  vim.hl.priorities.user = vim.hl.priorities.user or 101
end

local function flash(buf, row, start_col, end_col, duration)
  local n = get_ns()
  local hl = get_hl()
  local total = vim.api.nvim_buf_line_count(buf)
  row = math.min(row, total - 1)

  local s_col = math.max(0, start_col - 1)
  local e_col
  if end_col and end_col > start_col then
    e_col = end_col - 1
  else
    local line_text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    e_col = #line_text
  end
  if e_col < s_col then
    e_col = s_col
  end

  local win = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then
      win = w
      break
    end
  end

  pcall(vim.api.nvim_buf_clear_namespace, buf, n, row, row + 1)
  if vim.hl and vim.hl.range then
    pcall(vim.hl.range, buf, n, hl, { row, s_col }, { row, e_col - 1 }, {
      regtype = "v",
      inclusive = true,
      priority = 50000,
      timeout = duration,
    })
  end
  for i = 1, 5 do
    pcall(vim.api.nvim_buf_add_highlight, buf, n, hl, row, s_col, e_col)
  end

  if vim.fn.matchaddpos then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        local keym = "m_" .. buf .. "_" .. w
        if flash_timers[keym] then
          pcall(vim.fn.matchdelete, flash_timers[keym], w)
          flash_timers[keym] = nil
        end
        local ok_mid, mid =
          pcall(vim.fn.matchaddpos, hl, { { row + 1, s_col + 1, math.max(1, e_col - s_col + 1) } }, 100000)
        if ok_mid and type(mid) == "number" then
          flash_timers[keym] = mid
          vim.defer_fn(function()
            pcall(vim.fn.matchdelete, mid, w)
            if flash_timers[keym] == mid then
              flash_timers[keym] = nil
            end
          end, duration)
        end
      end
    end
  end

  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, n, row, row + 1)
    end
  end, duration)
end

local function strip_sound_modifiers(sound)
  if type(sound) ~= "string" then
    return sound
  end
  return sound:gsub("[%*%/:%?@!%d]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function get_sound_tokens(text)
  local tokens = {}
  if type(text) ~= "string" then
    return tokens
  end
  for _, content in text:gmatch("([\"'])(.-)%1") do
    for token in content:gmatch("([^%s]+)") do
      table.insert(tokens, { token = token })
    end
  end
  if #tokens == 0 then
    for token in text:gmatch("([%w_%-]+)") do
      table.insert(tokens, { token = token })
    end
  end
  return tokens
end

function M.track(bufnr, line, orbit, text)
  if text == nil or #text == 0 then
    return
  end
  for _, track in ipairs(tracks) do
    if track.bufnr == bufnr and track.line == line then
      return
    end
  end
  table.insert(tracks, {
    bufnr = bufnr,
    line = line,
    orbit = orbit,
    text = text,
  })
end

function M.on_event(parsed)
  if parsed == nil or parsed.sound == nil then
    return
  end
  local delta = parsed.delta
  local duration = get_fade()
  if delta ~= nil and delta > 0 then
    duration = math.floor(delta * 1000)
  end

  local base = strip_sound_modifiers(parsed.sound)
  if base == nil or #base < 1 then
    base = parsed.sound
  end

  local function find_and_flash(track)
    if not vim.api.nvim_buf_is_valid(track.bufnr) then
      return false
    end
    local text = track.text or ""
    local bufnr = track.bufnr
    local line = track.line

    local tokens = get_sound_tokens(text)
    for _, tinfo in ipairs(tokens) do
      local token = tinfo.token
      local token_base = strip_sound_modifiers(token)
      if token_base == base or token == parsed.sound or token_base == parsed.sound then
        local col = text:find(token, 1, true)
        if col ~= nil then
          flash(bufnr, line, col, col + #token, duration)
          return true
        end
      end
    end

    local col = text:find(base, 1, true)
    if col ~= nil then
      flash(bufnr, line, col, col + #base, duration)
      return true
    end
    col = text:find(parsed.sound, 1, true)
    if col ~= nil then
      flash(bufnr, line, col, col + #parsed.sound, duration)
      return true
    end
    return false
  end

  local function try_highlight(track_list)
    for _, track in ipairs(track_list) do
      if find_and_flash(track) then
        return true
      end
    end
    return false
  end

  if parsed.orbit ~= nil then
    local orbit_tracks = {}
    for _, track in ipairs(tracks) do
      if track.orbit == parsed.orbit then
        table.insert(orbit_tracks, track)
      end
    end
    if #orbit_tracks > 0 and try_highlight(orbit_tracks) then
      return
    end
  end

  if try_highlight(tracks) then
    return
  end
end

function M.clear(orbit)
  local n = get_ns()
  if orbit ~= nil then
    for i = #tracks, 1, -1 do
      local track = tracks[i]
      if track.orbit == orbit then
        if vim.api.nvim_buf_is_valid(track.bufnr) then
          vim.api.nvim_buf_clear_namespace(track.bufnr, n, track.line, track.line + 1)
        end
        table.remove(tracks, i)
      end
    end
    return
  end
  for _, track in ipairs(tracks) do
    if vim.api.nvim_buf_is_valid(track.bufnr) then
      vim.api.nvim_buf_clear_namespace(track.bufnr, n, track.line, track.line + 1)
    end
  end
  tracks = {}
  for key in pairs(flash_timers) do
    clear_flash(key)
  end
end

function M.stop()
  M.clear()
end

return M