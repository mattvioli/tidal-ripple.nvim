local state = require("tidal.core.state")
local notify = require("tidal.util.notify")

local M = {}

local warned = { tidal = false, sclang = false }

local function repl(name)
  if name == "sclang" then
    return state.sclang
  end
  return state.ghci
end

local function check(name)
  if repl(name) then
    warned[name] = false
    return true
  end
  if state.launching then
    return false
  end
  if not warned[name] then
    warned[name] = true
    notify.warn(string.format("%s REPL is not running; send dropped. Launch with ':TidalLaunch'", name))
  end
  return false
end

M.tidal = {}

function M.tidal.send(text)
  if not check("tidal") then
    return
  end
  state.ghci:send(text)
end

function M.tidal.send_line(text)
  if not check("tidal") then
    return
  end
  state.ghci:send_line(text)
end

function M.tidal.send_multiline(lines)
  if not check("tidal") then
    return
  end
  state.ghci:send_multiline(lines)
end

M.sclang = {}

function M.sclang.send(text)
  if not check("sclang") then
    return
  end
  state.sclang:send(text)
end

function M.sclang.send_line(text)
  if not check("sclang") then
    return
  end
  state.sclang:send_line(text)
end

function M.sclang.send_multiline(lines)
  if not check("sclang") then
    return
  end
  state.sclang:send_multiline(lines)
end

return M
