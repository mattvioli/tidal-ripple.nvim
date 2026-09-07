local config = require("tidal.config")
local state = require("tidal.core.state")
local notify = require("tidal.util.notify")
local Packet = require("tidal.lib.losc.packet")
local ctrl = require("tidal.core.ctrl")

local M = {}

local function parse_dirt_play(msg)
  if #msg < 4 then
    return nil
  end

  local result = {
    orbit = tonumber(msg[2]),
  }

  for i = 3, #msg - 1, 2 do
    local key = msg[i]
    local val = msg[i + 1]
    if type(key) == "string" then
      if key == "cps" then
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
  end

  return result
end

local function dispatch(msg)
  if msg.address == "/ctrl" then
    ctrl.dispatch(msg)
    return
  end

  if msg.address ~= "/dirt/play" then
    return
  end
  local parsed = parse_dirt_play(msg)
  if not parsed then
    return
  end

  if config.options.osc.debug then
    vim.schedule(function()
      vim.notify(
        string.format(
          "OSC /dirt/play: sound=%s n=%s cycle=%s cps=%s orbit=%s delta=%s",
          vim.inspect(parsed.sound),
          vim.inspect(parsed.n),
          vim.inspect(parsed.cycle),
          vim.inspect(parsed.cps),
          vim.inspect(parsed.orbit),
          vim.inspect(parsed.delta)
        ),
        vim.log.levels.DEBUG
      )
    end)
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
      dispatch(elem)
    end
  else
    dispatch(result)
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
