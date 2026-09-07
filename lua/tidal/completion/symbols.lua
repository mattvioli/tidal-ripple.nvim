local M = {}

local symbols = {}

local function extract_param_value(line, param_name)
  return line:match("%f[%w]" .. param_name .. '%s+"([^"]+)"')
end

local function parse_let_line(line)
  line = line:gsub("%-%-.*$", "")
  local name = line:match("^%s*let%s+([%w_%-]+)%s*=%s*(.*)$")
  local rest
  if name then
    rest = line:match("^%s*let%s+[%w_%-]+%s*=%s*(.*)$")
  else
    name, rest = line:match("^%s*([%w_%-]+)%s*=%s*(.*)$")
  end
  if not name or not rest then
    return nil
  end

  local info = { name = name, raw = rest }
  local sound_val = extract_param_value(rest, "sound") or extract_param_value(rest, "s")
  if sound_val then
    info.type = "sound"
    info.bank = sound_val:match("^([%w_%-]+)")
  end
  local note_val = extract_param_value(rest, "note") or extract_param_value(rest, "n")
  if note_val then
    info.type = info.type and (info.type .. "_note") or "note"
    info.notes = note_val
  end
  return info
end

local function parse_p_line(line)
  line = line:gsub("%-%-.*$", "")
  local _, _, name, rest = line:find('p%s+"([^"]+)"%s+$%s*(.*)')
  if not name then
    _, _, name, rest = line:find("p%s+(%w+)%s+%$%s*(.*)")
  end
  if not name or not rest then
    return nil
  end
  local info = { name = name, raw = rest }
  local sound_val = extract_param_value(rest, "sound") or extract_param_value(rest, "s")
  if sound_val then
    info.type = "sound"
    info.bank = sound_val:match("^([%w_%-]+)")
  end
  return info
end

local function starts_let_block(line)
  local stripped = line:gsub("^%s*", "")
  if not stripped:match("^let") then
    return false
  end
  if stripped:match("^let%s+in") then
    return false
  end
  local rest = stripped:sub(4)
  return rest == "" or rest:match("^%s+[%w_%-]+") ~= nil
end

function M.scan_buffer(buf)
  symbols = {}
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local let_lines = {}

  local in_let = false

  local function flush_let_lines()
    if #let_lines == 0 then
      return
    end
    for _, l in ipairs(let_lines) do
      local info = parse_let_line(l)
      if info then
        symbols[info.name] = info
      end
    end
    let_lines = {}
  end

  for _, line in ipairs(lines) do
    local stripped = line:gsub("^%s*", "")

    if stripped == "" or stripped:match("^%-%-") then
      if in_let then
        let_lines[#let_lines + 1] = line
      end
    elseif starts_let_block(line) then
      if in_let then
        flush_let_lines()
      end
      in_let = true
      let_lines = { line }
    elseif in_let then
      if stripped == "in" or stripped:match("^in%s") then
        in_let = false
      else
        let_lines[#let_lines + 1] = line
      end
    end

    if not in_let then
      flush_let_lines()
      local info = parse_p_line(line)
      if info then
        symbols[info.name] = info
      end
      info = parse_let_line(line)
      if info then
        symbols[info.name] = info
      end
    end
  end

  flush_let_lines()
end

function M.get_symbol(name)
  return symbols[name]
end

function M.get_all_symbols()
  local result = {}
  for name, info in pairs(symbols) do
    table.insert(result, { word = name, menu = "pat", info = info.type or "pattern" })
  end
  table.sort(result, function(a, b)
    return a.word < b.word
  end)
  return result
end

function M.get_symbol_names()
  local names = {}
  for name in pairs(symbols) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.get_bank_for_symbol(name)
  local sym = symbols[name]
  if sym and sym.bank then
    return sym.bank
  end
  return nil
end

return M
