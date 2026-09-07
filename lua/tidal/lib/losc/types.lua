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
local Timetag = require(relpath .. ".timetag")

local _pack = Serializer.pack()
local _unpack = Serializer.unpack()
local has_string_pack = string.pack and true or false

local Types = {}

Types.pack = {}
setmetatable(Types.pack, {
  __call = function(self, type, value)
    return pcall(self[type], value)
  end,
})

Types.unpack = {}
setmetatable(Types.unpack, {
  __call = function(self, type, data, offset)
    return pcall(self[type], data, offset)
  end,
})

function Types.get(tbl)
  local types = {}
  for k, _ in pairs(tbl) do
    types[#types + 1] = k
  end
  return types
end

local function strsize(s)
  return 4 * (math.floor(#s / 4) + 1)
end

local function blobsize(b)
  return 4 * (math.floor((#b + 3) / 4))
end

Types.pack.i = function(value)
  return _pack(">i4", value)
end

Types.unpack.i = function(data, offset)
  return _unpack(">i4", data, offset)
end

Types.pack.f = function(value)
  return _pack(">f", value)
end

Types.unpack.f = function(data, offset)
  return _unpack(">f", data, offset)
end

Types.pack.s = function(value)
  local len = strsize(value)
  local fmt = "c" .. len
  value = value .. string.rep(string.char(0), len - #value)
  return _pack(">" .. fmt, value)
end

Types.unpack.s = function(data, offset)
  local fmt = has_string_pack and "z" or "s"
  local str = _unpack(">" .. fmt, data, offset)
  return str, strsize(str) + (offset or 1)
end

Types.pack.b = function(value)
  local size = #value
  local aligned = blobsize(value)
  local fmt = "c" .. aligned
  value = value .. string.rep(string.char(0), aligned - size)
  return _pack(">I4" .. fmt, size, value)
end

Types.unpack.b = function(data, offset)
  local size, blob
  size, offset = _unpack(">I4", data, offset)
  blob, offset = _unpack(">c" .. size, data, offset)
  return blob, offset + blobsize(blob) - size
end

if has_string_pack then
  Types.pack.h = function(value)
    return _pack(">i8", value)
  end
end

if has_string_pack then
  Types.unpack.h = function(data, offset)
    return _unpack(">i8", data, offset)
  end
end

Types.pack.t = function(value)
  return Timetag.pack(value)
end

Types.unpack.t = function(data, offset)
  return Timetag.unpack(data, offset)
end

Types.pack.d = function(value)
  return _pack(">d", value)
end

Types.unpack.d = function(data, offset)
  return _unpack(">d", data, offset)
end

Types.unpack.T = function(_, offset)
  return true, offset or 0
end

Types.unpack.F = function(_, offset)
  return false, offset or 0
end

Types.unpack.N = function(_, offset)
  return false, offset or 0
end

Types.unpack.I = function(_, offset)
  return math.huge, offset or 0
end

return Types
