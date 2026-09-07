local parser = require("tidal.completion.parser")

local M = {}

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  local ft = vim.bo.filetype
  return ft == "haskell" or ft == "tidal"
end

function source:get_trigger_characters()
  return { '"', "$", "#" }
end

local function should_offer(ctx)
  if not ctx or not ctx.type then
    return false
  end
  if ctx.type == "empty" then
    return false
  end
  if ctx.type == "param" or ctx.type == "function" then
    return true
  end
  if ctx.type == "sample" or ctx.type == "index" or ctx.type == "param_value" then
    return (ctx.prefix or "") ~= ""
  end
  if ctx.type == "keyword" then
    return (ctx.prefix or ""):len() >= 1
  end
  return false
end

function source:complete(params, callback)
  local c = params.context
  local ctx = parser.get_context(c.bufnr, c.cursor.row, c.cursor.col)

  if not should_offer(ctx) then
    callback()
    return
  end

  local comps = parser.get_completions(ctx)
  local items = {}
  for _, it in ipairs(comps) do
    table.insert(items, {
      word = it.word,
      label = it.word,
      menu = it.menu or "",
      info = it.info or "",
      documentation = it.info or "",
    })
  end

  callback({ items = items, isIncomplete = false })
end

function M.new()
  return source.new()
end

function M.register()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return false
  end
  local config = require("tidal.config")
  local name = (config.options.completion or {}).source_name or "tidal"
  cmp.register_source(name, source.new())
  return true
end

return M
