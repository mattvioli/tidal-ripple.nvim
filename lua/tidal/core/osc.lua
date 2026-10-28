local config = require("tidal.config")
local state = require("tidal.core.state")
local notify = require("tidal.util.notify")
local Packet = require("tidal.lib.losc.packet")
local ctrl = require("tidal.core.ctrl")

local M = {}

-- Parse a /dirt/play OSC message.
-- SuperDirt (SuperDOSC) sends:
--   [1] = orbit (int, e.g. 1 = d1)
--   [2] = "cps"        -> [3] = cps value (float)
--   [4] = "cycle"     -> [5] = cycle value (float)
--   [6] = "delta"     -> [7] = delta value (float)
--   [8] = "s"         -> [9] = sound name (string)
--   [10] = "n"        -> [11] = sample index (int)
--   ... plus other key-value pairs
--
-- In the raw OSC table from Packet.unpack, the orbit ends up at msg[1] (unkeyed)
-- and key-value pairs start at msg[2].
--
-- But we've also seen the "visualizer target" format where orbit is at [7]
-- and everything starts as [1] = "_id_", [2] = orbit_string.
--
-- Strategy: Try _id_ key first (visualizer format), then _id (no underscore),
-- then try msg[1] if it's a number (SuperDOSC format), then try msg[7] (old format).
local function parse_dirt_play(msg)
  if msg.address ~= "/dirt/play" then
    return nil
  end

  local result = {}

  for i = 1, #msg - 1, 2 do
    local key = msg[i]
    local val = msg[i + 1]
    if type(key) ~= "string" then
      -- Unkeyed value at odd index — could be orbit in some OSC formats
      if i == 1 then
        result.orbit = tonumber(key)
      end
    elseif key == "_id_" or key == "_id" then
      local orbit_val = tonumber(val)
      if orbit_val ~= nil then
        result.orbit = orbit_val
      end
    elseif key == "orbit" then
      result.orbit = tonumber(val)
    elseif key == "cps" then
      result.cps = tonumber(val)
    elseif key == "cycle" then
      result.cycle = tonumber(val)
    elseif key == "delta" then
      result.delta = tonumber(val)
    elseif key == "s" then
      result.sound = val
    elseif key == "n" then
      result.n = tonumber(val)
    end
  end

  -- Fallback: check msg[7] (old SuperDirt format where orbit is at index 7)
  if result.orbit == nil and #msg >= 7 then
    local seventh = msg[7]
    if type(seventh) ~= "string" then
      result.orbit = tonumber(seventh)
    end
  end

  -- Final fallback: _id_ without trailing underscore
  if result.orbit == nil and #msg >= 2 then
    local first = msg[1]
    if type(first) == "string" and first == "_id" then
      result.orbit = tonumber(msg[2])
    end
  end

  return result
end

--- Called via vim.schedule_wrap from on_read.
--- Sends OSC events downstream: playhead, event_highlight, visualizer.
local function on_dirt_play(msg)
  local parsed = parse_dirt_play(msg)
  if not parsed then
    return
  end



  state.current_cps = parsed.cps
  state.current_cycle = parsed.cycle

  local playhead = require("tidal.core.playhead")
  playhead.on_cycle(parsed)

  if config.options.event_highlight.enabled then
    require("tidal.core.event_highlight").on_event(parsed)
  end

  local viz_ok, viz = pcall(require, "tidal.core.visualizer")
  if viz_ok and viz.is_open() then
    viz.add_event(parsed)
  end
end

local scheduled_on_dirt_play = vim.schedule_wrap(on_dirt_play)

local scheduled_dispatch = vim.schedule_wrap(function(msg)
  if msg.address == "/ctrl" then
    ctrl.dispatch(msg)
    return
  end

  if msg.address ~= "/dirt/play" then
    return
  end

  scheduled_on_dirt_play(msg)
end)

local function on_read(err, data)
  if err or not data or #data == 0 then
    return
  end

  local ok, result = pcall(Packet.unpack, data)
  if not ok or not result then
    return
  end

  if result.timetag then
    for _, elem in ipairs(result) do
      scheduled_dispatch(elem)
    end
  else
    scheduled_dispatch(result)
  end
end

function M.start()
  if state.osc then
    return
  end

  local port = config.options.osc.port
  local udp = vim.uv.new_udp()
  if not udp then
    notify.error("OSC: failed to create UDP socket")
    return
  end

  local ok

  ok = udp:bind("127.0.0.1", port)
  if not ok then
    notify.error("OSC: failed to bind to port " .. port)
    udp:close()
    return
  end

  ok = udp:recv_start(on_read)
  if not ok then
    notify.error("OSC: failed to start receiving on port " .. port)
    udp:close()
    return
  end

  state.osc = udp
  state.osc_running = true

  notify.info(string.format("OSC listener started on port %d", port))
end

function M.stop()
  if not state.osc then
    return
  end

  state.osc:close()
  state.osc = nil
  state.osc_running = false
  state.current_cps = nil
  state.current_cycle = nil

  ctrl.reset()
  require("tidal.core.event_highlight").stop()

  notify.info("OSC listener stopped")
end

function M.restart()
  M.stop()
  M.start()
end

function M.is_running()
  return state.osc_running
end

return M
