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
local Message = require(relpath .. ".message")
local Bundle = require(relpath .. ".bundle")
local Types = require(relpath .. ".types")

local Packet = {}

function Packet.is_bundle(packet)
  if type(packet) == "string" then
    local value = Types.unpack.s(packet)
    return value == "#bundle"
  elseif type(packet) == "table" then
    packet = packet.content or packet
    return type(packet.timetag) == "table"
  end
end

function Packet.validate(packet)
  if Packet.is_bundle(packet) then
    Bundle.validate(packet)
  else
    Message.validate(packet)
  end
end

function Packet.pack(tbl)
  if Packet.is_bundle(tbl) then
    Bundle.validate(tbl)
    return Bundle.pack(tbl.content or tbl)
  else
    Message.validate(tbl)
    return Message.pack(tbl.content or tbl)
  end
end

function Packet.unpack(data)
  if Packet.is_bundle(data) then
    Bundle.validate(data)
    return Bundle.unpack(data)
  else
    Message.validate(data)
    return Message.unpack(data)
  end
end

return Packet
