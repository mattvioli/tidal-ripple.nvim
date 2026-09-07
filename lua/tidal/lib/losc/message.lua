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
local Types = require(relpath .. ".types")

local Message = {}
Message.__index = Message

function Message.new(msg)
  local self = setmetatable({}, Message)
  self.content = {}
  self.content.address = ""
  self.content.types = ""
  if msg then
    if type(msg) == "string" then
      if msg:sub(1, 1) ~= "/" then
        msg = "/" .. msg
      end
      Message.address_validate(msg)
      self.content.address = msg
    elseif type(msg) == "table" then
      Message.tbl_validate(msg)
      self.content = msg
    end
  end
  return self
end

function Message:add(type, item)
  self.content.types = self.content.types .. type
  if item then
    self.content[#self.content + 1] = item
  else
    if type == "T" or type == "F" then
      self.content[#self.content + 1] = type == "T"
    elseif type == "N" then
      self.content[#self.content + 1] = false
    elseif type == "I" then
      self.content[#self.content + 1] = math.huge
    end
  end
end

function Message:iter()
  local tbl = { self.content.types, self.content }
  local function msg_it(t, i)
    i = i + 1
    local type = t[1]:sub(i, i)
    local arg = t[2][i]
    if type ~= nil and arg ~= nil then
      return i, type, arg
    end
    return nil
  end
  return msg_it, tbl, 0
end

function Message:address()
  return self.content.address
end

function Message:types()
  return self.content.types
end

function Message:args()
  local args = {}
  for _, a in ipairs(self.content) do
    args[#args + 1] = a
  end
  return args
end

function Message.validate(message)
  assert(message)
  if type(message) == "string" then
    Message.bytes_validate(message)
  elseif type(message) == "table" then
    Message.tbl_validate(message.content or message)
  end
end

function Message.address_validate(addr)
  assert(not addr:find("[%s#*,%[%]{}%?]"), "Invalid characters found in address.")
end

function Message.tbl_validate(tbl)
  assert(tbl.address, 'Missing "address" field.')
  Message.address_validate(tbl.address)
  assert(tbl.types, 'Missing "types" field.')
  assert(#tbl.types == #tbl, "Types and arguments mismatch")
end

function Message.bytes_validate(bytes, offset)
  local value
  assert(#bytes % 4 == 0, "OSC message data must be a multiple of 4.")
  value, offset = Types.unpack.s(bytes, offset)
  assert(value:sub(1, 1) == "/", "Invalid OSC address.")
  value = Types.unpack.s(bytes, offset)
  assert(value:sub(1, 1) == ",", "Error: malformed type tag.")
end

function Message.pack(tbl)
  local packet = {}
  local address = tbl.address
  local types = tbl.types
  packet[#packet + 1] = Types.pack.s(address)
  packet[#packet + 1] = Types.pack.s("," .. types)
  local index = 1
  for type in types:gmatch(".") do
    local item = tbl[index]
    if item ~= nil then
      if Types.pack[type] then
        packet[#packet + 1] = Types.pack[type](item)
      end
      index = index + 1
    end
  end
  return table.concat(packet, "")
end

function Message.unpack(data, offset)
  local value
  local message = {}
  value, offset = Types.unpack.s(data, offset)
  message.address = value
  value, offset = Types.unpack.s(data, offset)
  local types = value:sub(2)
  message.types = types
  for type in types:gmatch(".") do
    if Types.unpack[type] then
      value, offset = Types.unpack[type](data, offset)
      message[#message + 1] = value
    end
  end
  return message, offset
end

return Message
