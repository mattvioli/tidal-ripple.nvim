--[[
MIT License

Copyright (c) 2021 David Granström

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local relpath = (...):gsub("%.[^%.]+$", "")
local Serializer = require(relpath .. ".serializer")
local _pack = Serializer.pack()
local _unpack = Serializer.unpack()

local Timetag = {}

local NTP_SEC_OFFSET = 2208988800
local TWO_POW_32 = 4294967296

local function tt_add(timetag, seconds)
  local sec = math.floor(seconds)
  local frac = math.floor(TWO_POW_32 * (seconds - sec) + 0.5)
  sec = sec + timetag.content.seconds
  frac = frac + timetag.content.fractions
  return Timetag.new_raw(sec, frac)
end

Timetag.__index = Timetag

Timetag.__add = function(a, b)
  if type(a) == "number" then
    return tt_add(b, a)
  end
  if type(b) == "number" then
    return tt_add(a, b)
  end
end

function Timetag.new_raw(...)
  local self = setmetatable({}, Timetag)
  local args = { ... }
  self.content = { seconds = 0, fractions = 1 }
  if #args >= 1 then
    if type(args[1]) == "table" then
      self.content = args[1]
    elseif type(args[1]) == "number" and not args[2] then
      self.content.seconds = args[1]
    elseif type(args[1]) == "number" and type(args[2]) == "number" then
      self.content.seconds = args[1]
      self.content.fractions = args[2]
    end
  end
  return self
end

function Timetag.new(seconds, fractions, precision)
  precision = precision or 1000
  if not seconds and not fractions then
    return Timetag.new_raw()
  end
  local secs, frac
  secs = (seconds or 0) + NTP_SEC_OFFSET
  frac = math.floor((fractions or 0) * (TWO_POW_32 / precision) + 0.5)
  return Timetag.new_raw(secs, frac)
end

function Timetag.new_from_timestamp(time, precision)
  precision = precision or 1000
  local seconds = math.floor(time / precision)
  local fracs = math.floor(precision * (time / precision - seconds) + 0.5)
  return Timetag.new(seconds, fracs)
end

function Timetag:timestamp(precision)
  return Timetag.get_timestamp(self.content, precision)
end

function Timetag:seconds()
  return self.content.seconds
end

function Timetag:fractions()
  return self.content.fractions
end

function Timetag.get_timestamp(tbl, precision)
  precision = precision or 1000
  local seconds = precision * math.max(0, tbl.seconds - NTP_SEC_OFFSET)
  local fractions = math.floor(precision * (tbl.fractions / TWO_POW_32) + 0.5)
  return seconds + fractions
end

function Timetag.pack(tbl)
  local data = {}
  data[#data + 1] = _pack(">I4", tbl.seconds)
  data[#data + 1] = _pack(">I4", tbl.fractions)
  return table.concat(data, "")
end

function Timetag.unpack(data, offset)
  local seconds, fractions
  seconds, offset = _unpack(">I4", data, offset)
  fractions, offset = _unpack(">I4", data, offset)
  return { seconds = seconds, fractions = fractions }, offset
end

return Timetag
