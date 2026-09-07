local notify = require("tidal.util.notify")

local M = {}

function M.parse_cards()
  local ok, result = pcall(vim.fn.readfile, "/proc/asound/cards")
  if not ok or not result then
    return {}
  end

  local cards = {}
  for _, line in ipairs(result) do
    local idx, name = line:match("^%s*(%d)%s+%[([^%]]+)%]")
    if idx and name then
      name = vim.trim(name)
      local desc = line:match("%]:%s*(.*)")
      table.insert(cards, {
        index = tonumber(idx),
        name = name,
        description = (desc or name),
      })
    end
  end
  return cards
end

function M.select(cards, callback)
  if #cards == 0 then
    callback(nil)
    return
  end

  if #cards == 1 then
    callback(cards[1].name)
    return
  end

  local items = vim.tbl_map(function(c)
    return string.format("hw:%s — %s", c.name, c.description)
  end, cards)

  vim.ui.select(items, {
    prompt = "Select soundcard for Jackd:",
  }, function(choice, idx)
    if not choice then
      callback(nil)
      return
    end
    callback(cards[idx].name)
  end)
end

function M.launch_jackd(card_name)
  local max_attempts = 3
  local attempt = 1

  while attempt <= max_attempts do
    if attempt > 1 then
      notify.info(string.format("[jackd] retrying (attempt %d/%d)...", attempt, max_attempts))
      vim.wait(2000, function()
        return false
      end, 50)
    end

    vim.fn.system("jack_control stop 2>/dev/null; true")
    vim.fn.system("pkill -x jackd 2>/dev/null; true")
    vim.wait(500, function()
      return false
    end, 50)

    local ok = pcall(function()
      local job_id = vim.fn.jobstart({
        "jackd",
        "-d",
        "alsa",
        "-d",
        "hw:" .. card_name,
      }, {
        detach = true,
        on_stderr = function(_, data)
          if data then
            for _, line in ipairs(data) do
              if line and line ~= "" then
                notify.info("[jackd] " .. line)
              end
            end
          end
        end,
      })
      if job_id <= 0 then
        error("failed to start jackd")
      end
    end)

    if not ok then
      notify.warn("jackd not found; SuperCollider will manage audio itself")
      return false
    end

    local ready = vim.wait(5000, function()
      vim.fn.system("jack_wait -c 2>/dev/null; true")
      return vim.v.shell_error == 0
    end, 100)

    if ready then
      return true
    end

    attempt = attempt + 1
  end

  notify.error(string.format("jackd failed to start after %d attempts", max_attempts))
  return false
end

return M
