local M = {}

local function token_at_cursor(tokens, cursor_col, str_start_col)
  local abs_pos = cursor_col
  for _, tok in ipairs(tokens) do
    if abs_pos >= tok.start and abs_pos <= tok.finish then
      return tok
    end
  end
  return nil
end

local function lex(str)
  local tokens = {}
  local i = 1
  while i <= #str do
    local c = str:sub(i, i)
    if c == " " then
      i = i + 1
    elseif c == "~" then
      table.insert(tokens, { type = "rest", value = "~", start = i, finish = i })
      i = i + 1
    elseif c == "[" then
      table.insert(tokens, { type = "open_bracket", value = "[", start = i, finish = i })
      i = i + 1
    elseif c == "]" then
      table.insert(tokens, { type = "close_bracket", value = "]", start = i, finish = i })
      i = i + 1
    elseif c == "<" then
      table.insert(tokens, { type = "open_angle", value = "<", start = i, finish = i })
      i = i + 1
    elseif c == ">" then
      table.insert(tokens, { type = "close_angle", value = ">", start = i, finish = i })
      i = i + 1
    elseif c == "{" then
      table.insert(tokens, { type = "open_brace", value = "{", start = i, finish = i })
      i = i + 1
    elseif c == "}" then
      table.insert(tokens, { type = "close_brace", value = "}", start = i, finish = i })
      i = i + 1
    elseif c == "," then
      table.insert(tokens, { type = "comma", value = ",", start = i, finish = i })
      i = i + 1
    elseif c == "|" then
      table.insert(tokens, { type = "pipe", value = "|", start = i, finish = i })
      i = i + 1
    elseif c == "." then
      table.insert(tokens, { type = "dot", value = ".", start = i, finish = i })
      i = i + 1
    elseif c == "_" then
      table.insert(tokens, { type = "tie", value = "_", start = i, finish = i })
      i = i + 1
    elseif c == "(" then
      local close = str:find(")", i)
      if close then
        table.insert(tokens, { type = "euclid", value = str:sub(i, close), start = i, finish = close })
        i = close + 1
      else
        table.insert(tokens, { type = "error", value = "(", start = i, finish = i })
        i = i + 1
      end
    elseif c == "*" then
      table.insert(tokens, { type = "repeat", value = "*", start = i, finish = i })
      i = i + 1
    elseif c == "/" then
      table.insert(tokens, { type = "divide", value = "/", start = i, finish = i })
      i = i + 1
    elseif c == ":" then
      table.insert(tokens, { type = "colon", value = ":", start = i, finish = i })
      i = i + 1
    elseif c == "!" then
      table.insert(tokens, { type = "replicate", value = "!", start = i, finish = i })
      i = i + 1
    elseif c == "@" then
      table.insert(tokens, { type = "elongate", value = "@", start = i, finish = i })
      i = i + 1
    elseif c == "?" then
      table.insert(tokens, { type = "random", value = "?", start = i, finish = i })
      i = i + 1
    elseif c == "%" then
      table.insert(tokens, { type = "percent", value = "%", start = i, finish = i })
      i = i + 1
    elseif
      c == "0"
      or c == "1"
      or c == "2"
      or c == "3"
      or c == "4"
      or c == "5"
      or c == "6"
      or c == "7"
      or c == "8"
      or c == "9"
      or c == "-"
      or c == "."
    then
      local num_start = i
      if c == "-" then
        i = i + 1
      end
      while i <= #str and (str:sub(i, i):match("[0-9.]")) do
        i = i + 1
      end
      local num = str:sub(num_start, i - 1)
      table.insert(tokens, { type = "number", value = num, start = num_start, finish = i - 1 })
    else
      local w_start = i
      while i <= #str and str:sub(i, i):match("[%w_%-]") do
        i = i + 1
      end
      local word = str:sub(w_start, i - 1)
      table.insert(tokens, { type = "word", value = word, start = w_start, finish = i - 1 })
    end
  end
  return tokens
end

function M.get_context(str, cursor_pos)
  if not str or #str == 0 then
    return { type = "empty" }
  end

  local tokens = lex(str)

  if cursor_pos then
    local tok = token_at_cursor(tokens, cursor_pos, 0)
    if tok then
      if tok.type == "word" then
        return { type = "word", value = tok.value, tokens = tokens }
      elseif tok.type == "number" then
        return { type = "number", value = tok.value, tokens = tokens }
      elseif tok.type == "rest" then
        return { type = "rest", tokens = tokens }
      elseif tok.type == "colon" then
        local prev = nil
        for _, t in ipairs(tokens) do
          if t == tok then
            break
          end
          prev = t
        end
        return { type = "index", sample = prev and prev.value, tokens = tokens }
      elseif tok.type == "repeat" or tok.type == "replicate" or tok.type == "divide" then
        return { type = "modifier", operator = tok.type, tokens = tokens }
      else
        return { type = "symbol", tokens = tokens }
      end
    end
    return { type = "whitespace", tokens = tokens }
  end

  return { type = "unknown", tokens = tokens }
end

function M.extract_sample_names(str)
  if not str then
    return {}
  end
  local names = {}
  local tokens = lex(str)
  for _, tok in ipairs(tokens) do
    if tok.type == "word" then
      local name = tok.value:match("^([%w_%-]+)")
      if name then
        names[name] = (names[name] or 0) + 1
      end
    end
  end
  local result = {}
  for name in pairs(names) do
    table.insert(result, name)
  end
  return result
end

function M.extract_sample_indices(str)
  if not str then
    return {}
  end
  local indices = {}
  local tokens = lex(str)
  for i, tok in ipairs(tokens) do
    if tok.type == "word" and tokens[i + 1] and tokens[i + 1].type == "colon" then
      if tokens[i + 2] and (tokens[i + 2].type == "number" or tokens[i + 2].type == "word") then
        indices[tok.value] = tokens[i + 2].value
      end
    elseif tok.type == "number" then
      table.insert(indices, tonumber(tok.value))
    end
  end
  return indices
end

return M
