local Buffer = require("tidal.util.buffer")

local Repl = {}
Repl.__index = Repl

local READY_POLL_MS = 100
local READY_TIMEOUT_MS = 20000

local function default_ready_when(self)
  return function()
    local bufnr = self.buf.bufnr
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
      return false
    end
    local count = vim.api.nvim_buf_line_count(bufnr)
    if count == 0 then
      return false
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(count, 200), false)
    for _, line in ipairs(lines) do
      if line:match("%S") then
        return true
      end
    end
    return false
  end
end

function Repl:new(opts)
  opts = opts or {}
  local obj = {}
  setmetatable(obj, self)
  obj.buf = Buffer.new({ name = opts.name, scratch = true, listed = false })
  obj.opts = opts
  obj.win_id = nil
  obj.pending = nil
  obj.ready = false
  return obj
end

function Repl:start(opts)
  if self.proc == nil then
    local win_opts = opts or {}
    self.win_id = self.buf:show(win_opts)
    self.pending = {}
    self.ready = false
    self.proc = vim.fn.jobstart(vim.list_extend({ self.opts.cmd }, self.opts.args or {}), {
      term = true,
      on_exit = function(code, signal)
        self.proc = nil
        self.win_id = nil
        self.ready = false
        self.pending = nil
        if self.opts.on_exit then
          self.opts.on_exit(code, signal)
        end
      end,
    })
    self:_watch_readiness()
  end
  return self
end

function Repl:_watch_readiness()
  local started = vim.uv.now()
  local ready_when = self.opts.ready_when or default_ready_when(self)
  local timeout = self.opts.ready_timeout_ms or READY_TIMEOUT_MS

  local timer = vim.uv.new_timer()
  local function poll()
    if not self.proc then
      if timer then
        timer:stop()
        timer:close()
      end
      return
    end
    local is_ready = false
    local ok, result = pcall(ready_when)
    if ok then
      is_ready = result
    end
    if is_ready or (vim.uv.now() - started) > timeout then
      timer:stop()
      timer:close()
      self.ready = true
      self:_flush()
    end
  end
  timer:start(READY_POLL_MS, READY_POLL_MS, vim.schedule_wrap(poll))
end

function Repl:send(text)
  if self.proc == nil then
    return self
  end
  if self.pending and not self.ready then
    table.insert(self.pending, text)
    return self
  end
  vim.api.nvim_chan_send(self.proc, text)
  self.buf:scroll_to_bottom()
  return self
end

function Repl:_flush()
  if not self.pending then
    return
  end
  local queued = self.pending
  self.pending = nil
  for _, text in ipairs(queued) do
    vim.api.nvim_chan_send(self.proc, text)
  end
  if self.buf then
    self.buf:scroll_to_bottom()
  end
end

function Repl:send_line(text)
  return self:send(text .. "\n")
end

function Repl:send_multiline(lines)
  return self:send_line(table.concat(lines, "\n"))
end

function Repl:exit()
  if self.proc then
    vim.fn.jobstop(self.proc)
  end
  return self
end

function Repl:is_running()
  return self.proc ~= nil
end

return Repl
