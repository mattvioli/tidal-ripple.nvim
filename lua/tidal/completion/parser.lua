local data = require("tidal.completion.data")
local mininotation = require("tidal.completion.mininotation")
local symbols = require("tidal.completion.symbols")
local sample_data = require("tidal.data.sample_banks")

local M = {}

local ts_available = false

local function check_ts()
  local ok = pcall(function()
    return vim.treesitter
  end)
  if not ok then
    return false
  end

  local has_parser = pcall(function()
    return vim.treesitter.get_parser(0, "haskell")
  end)

  if has_parser then
    ts_available = true
    return true
  end

  local ok2, langs = pcall(vim.treesitter.available_parsers or function()
    return {}
  end)
  if ok2 then
    for _, l in ipairs(langs) do
      if l == "haskell" then
        ts_available = true
        return true
      end
    end
  end
  return false
end

function M.is_ts_available()
  return ts_available
end

local param_names = {}
do
  for _, p in ipairs(data.control_params) do
    param_names[p.word] = true
    if p.aliases then
      for _, a in ipairs(p.aliases) do
        param_names[a] = true
      end
    end
  end
end

local function get_string_at_cursor_ts(buf, row, col)
  if not ts_available then
    return nil
  end
  local ok, root = pcall(function()
    local p = vim.treesitter.get_parser(buf, "haskell")
    return p:parse()[1]:root()
  end)
  if not ok or not root then
    return nil
  end

  local query = vim.treesitter.query.parse(
    "haskell",
    [[
    (string_literal) @string
  ]]
  )

  local best = nil
  for _, node in query:iter_captures(root, buf, row, row + 1) do
    if node then
      local start_row, start_col, end_row, end_col = node:range()
      if start_row <= row and end_row >= row then
        local in_range = false
        if row > start_row and row < end_row then
          in_range = true
        elseif row == start_row and row == end_row then
          in_range = col >= start_col and col <= end_col
        elseif row == start_row then
          in_range = col >= start_col
        elseif row == end_row then
          in_range = col <= end_col
        end
        if in_range then
          if
            not best
            or (start_row > best.start_row)
            or (start_row == best.start_row and start_col > best.start_col)
          then
            best = { node = node, start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col }
          end
        end
      end
    end
  end
  return best
end

local function get_string_content_at_cursor_ts(buf, row, col)
  local info = get_string_at_cursor_ts(buf, row, col)
  if not info then
    return nil
  end

  local text = vim.treesitter.get_node_text(info.node, buf)
  local inner = text:sub(2, #text - 1)
  local cursor_inner_col = col - info.start_col - 1

  local prev_node = info.node:prev_sibling()
  local param_name = nil

  if prev_node then
    local ptext = vim.treesitter.get_node_text(prev_node, buf)
    if param_names[ptext] then
      param_name = ptext
    end
  end

  if not param_name then
    local parent = info.node:parent()
    while parent do
      local children = {}
      for child in parent:iter_children() do
        table.insert(children, child)
      end
      for i, child in ipairs(children) do
        if child == info.node and i > 1 then
          local prev = children[i - 1]
          local ptext = vim.treesitter.get_node_text(prev, buf)
          if param_names[ptext] then
            param_name = ptext
            break
          end
        end
      end
      if param_name then
        break
      end
      parent = parent:parent()
    end
  end

  local miniton = mininotation.get_context(inner, cursor_inner_col)

  return {
    param = param_name,
    inner = inner,
    cursor_col = cursor_inner_col,
    miniton = miniton,
    node = info.node,
  }
end

local function find_param_on_line_ts(buf, row, target_param)
  if not ts_available then
    return nil
  end
  local ok, root = pcall(function()
    local p = vim.treesitter.get_parser(buf, "haskell")
    return p:parse()[1]:root()
  end)
  if not ok or not root then
    return nil
  end

  local query = vim.treesitter.query.parse(
    "haskell",
    [[
    (string_literal) @str
  ]]
  )

  local strings = {}
  for _, node in query:iter_captures(root, buf, row, row + 1) do
    if node then
      local srow = node:range()
      table.insert(strings, { node = node, row = srow })
    end
  end

  for _, sinfo in ipairs(strings) do
    local prev = sinfo.node:prev_sibling()
    if prev then
      local ptext = vim.treesitter.get_node_text(prev, buf)
      if ptext == target_param then
        local text = vim.treesitter.get_node_text(sinfo.node, buf)
        return text:sub(2, #text - 1)
      end
    end
  end
  return nil
end

local function find_param_on_line_fallback(buf, row, target_param)
  local lines = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)
  if #lines == 0 then
    return nil
  end
  local line = lines[1]
  local _, _, val = line:find(target_param .. '%s+"([^"]*)"')
  return val
end

local function find_param_on_line(buf, row, target_param)
  local val = find_param_on_line_ts(buf, row - 1, target_param)
  if val then
    return val
  end
  return find_param_on_line_fallback(buf, row, target_param)
end

local function get_context_fallback(buf, row, col)
  local lines = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)
  if #lines == 0 then
    return { type = "empty" }
  end
  local line = lines[1]

  local text_before = line:sub(1, col + 1)

  local in_string = false
  local string_start = nil
  local param_name = nil

  for i = 1, col + 1 do
    local c = line:sub(i, i)
    if c == '"' then
      if not in_string then
        in_string = true
        string_start = i
        local before = line:sub(1, i - 1)
        local pname = before:match("([%w_%-]+)%s*$")
        if pname and param_names[pname] then
          param_name = pname
        end
      else
        in_string = false
        string_start = nil
      end
    end
  end

  if in_string and string_start then
    local inner = line:sub(string_start + 1, col + 1)
    local prefix = inner:match("([%w_%-:]*)$") or ""
    if param_name == "s" or param_name == "sound" then
      return { type = "sample", prefix = prefix, param = param_name }
    elseif param_name == "n" or param_name == "note" then
      local s_val = find_param_on_line_fallback(buf, row, "s") or find_param_on_line_fallback(buf, row, "sound")
      return { type = "index", prefix = prefix, bank = s_val, param = param_name }
    elseif param_name then
      return { type = "param_value", prefix = prefix, param = param_name }
    end
    return { type = "string", prefix = prefix, param = param_name }
  end

  local param_prefix = text_before:match("#%s+([%w_%-]*)$")
  if text_before:match("#%s*$") or (param_prefix and param_prefix ~= "") then
    return { type = "param", prefix = param_prefix or "" }
  end

  local func_prefix = text_before:match("%$%s+([%w_%-]*)$")
  if text_before:match("%$%s*$") or (func_prefix and func_prefix ~= "") then
    return { type = "function", prefix = func_prefix or "" }
  end

  local prefix = text_before:match("([%w_%-]+)$")
  return { type = "keyword", prefix = prefix or "" }
end

local function string_prefix(inner, cursor_inner)
  local content = inner:sub(1, cursor_inner)
  return content:match("([%w_%-:]*)$") or ""
end

function M.get_context(buf, row, col)
  if not buf then
    buf = 0
  end

  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  if #line == 0 then
    return { type = "empty" }
  end

  local ts_str = nil
  if ts_available then
    ts_str = get_string_content_at_cursor_ts(buf, row - 1, col)
  end

  if ts_str and ts_str.param then
    local prefix = string_prefix(ts_str.inner, ts_str.cursor_col)
    if ts_str.param == "s" or ts_str.param == "sound" then
      return { type = "sample", prefix = prefix, param = ts_str.param }
    elseif ts_str.param == "n" or ts_str.param == "note" then
      local s_val = find_param_on_line(buf, row, "s") or find_param_on_line(buf, row, "sound")
      return { type = "index", prefix = prefix, bank = s_val, param = ts_str.param }
    elseif ts_str.param then
      return { type = "param_value", prefix = prefix, param = ts_str.param }
    end
  end

  return get_context_fallback(buf, row, col)
end

function M.get_completions(ctx)
  if not ctx or ctx.type == "empty" then
    return {}
  end

  local prefix = (ctx.prefix or ""):lower()

  if ctx.type == "sample" then
    local banks = sample_data.get_banks()
    local results = {}
    for _, b in ipairs(banks) do
      if b.name:lower():find(prefix, 1, true) == 1 then
        table.insert(results, {
          word = b.name,
          menu = "[bank]",
          info = b.description or "",
        })
      end
    end
    return results
  end

  if ctx.type == "index" then
    local bank = ctx.bank
    if bank then
      local files = sample_data.get_files(bank)
      if #files > 0 then
        local results = {}
        for i, fname in ipairs(files) do
          local label = tostring(i - 1)
          if not prefix or label:find(prefix, 1, true) == 1 then
            table.insert(results, {
              word = label,
              menu = "[idx]",
              info = fname,
            })
          end
          local letter = string.char(96 + i)
          if not prefix or letter:find(prefix, 1, true) == 1 then
            table.insert(results, {
              word = letter,
              menu = "[idx]",
              info = fname,
            })
          end
        end
        return results
      end
    end
    local results = {}
    for i = 0, 255 do
      local s = tostring(i)
      if not prefix or s:find(prefix, 1, true) == 1 then
        table.insert(results, { word = s, menu = "[idx]", info = "Sample index" })
      end
    end
    return results
  end

  if ctx.type == "param" then
    local results = {}
    for _, p in ipairs(data.control_params) do
      if not prefix or p.word:lower():find(prefix, 1, true) == 1 then
        table.insert(results, {
          word = p.word,
          menu = "[" .. (p.menu or "") .. "]",
          info = p.info or "",
        })
      end
      if p.aliases then
        for _, a in ipairs(p.aliases) do
          if not prefix or a:lower():find(prefix, 1, true) == 1 then
            table.insert(results, {
              word = a,
              menu = "[" .. (p.menu or "") .. "]",
              info = "alias for " .. p.word,
            })
          end
        end
      end
    end
    return results
  end

  if ctx.type == "function" then
    local results = {}
    local seen = {}

    local function add(list, menu_prefix)
      for _, item in ipairs(list) do
        local word = item.word
        if not seen[word] and (not prefix or word:lower():find(prefix, 1, true) == 1) then
          seen[word] = true
          table.insert(results, {
            word = word,
            menu = "[" .. menu_prefix .. "]",
            info = item.info or "",
          })
        end
      end
    end

    add(data.pattern_functions, "fun")
    add(data.top_level, "cmd")
    add(data.oscillators, "osc")
    add(data.orbit_aliases, "orbit")
    add(data.control_params, "param")

    for _, s in ipairs(symbols.get_all_symbols()) do
      if not seen[s.word] and (not prefix or s.word:lower():find(prefix, 1, true) == 1) then
        seen[s.word] = true
        table.insert(results, s)
      end
    end

    return results
  end

  if ctx.type == "keyword" then
    local results = {}
    local seen = {}

    local function add(list, menu_prefix)
      for _, item in ipairs(list) do
        if not seen[item.word] and (not prefix or item.word:lower():find(prefix, 1, true) == 1) then
          seen[item.word] = true
          table.insert(results, {
            word = item.word,
            menu = "[" .. menu_prefix .. "]",
            info = item.info or "",
          })
        end
      end
    end

    add(data.control_params, "param")
    add(data.pattern_functions, "fun")
    add(data.orbit_aliases, "orbit")
    add(data.top_level, "cmd")
    add(data.oscillators, "osc")

    local syms = symbols.get_all_symbols()
    for _, s in ipairs(syms) do
      if not seen[s.word] and (not prefix or s.word:lower():find(prefix, 1, true) == 1) then
        seen[s.word] = true
        table.insert(results, s)
      end
    end

    return results
  end

  return {}
end

check_ts()

return M
