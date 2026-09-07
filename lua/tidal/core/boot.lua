local Ghci = require("tidal.util.repl.ghci")
local Sclang = require("tidal.util.repl.sclang")
local soundcard = require("tidal.core.soundcard")
local state = require("tidal.core.state")
local config = require("tidal.config")
local notify = require("tidal.util.notify")

local M = {}

function M.tidal(opts, split)
  if not opts.enabled then
    return
  end
  state.ghci = Ghci:new({
    name = "tidal",
    cmd = opts.cmd,
    args = vim.list_extend({
      "-XOverloadedStrings",
      "-ghci-script=" .. vim.fn.expand(opts.file),
    }, opts.args or {}),
    on_exit = function(_code, _signal)
      state.ghci = nil
      state.ghci_win = nil
    end,
  })
  local win_opts = { split = split or config.options.boot.split or "h" }
  state.ghci:start(win_opts)
  state.ghci_buf = state.ghci.buf.bufnr
  state.ghci_win = state.ghci.win_id
end

local function start_sclang(opts, split)
  state.sclang = Sclang:new({
    name = "sclang",
    cmd = opts.cmd,
    args = vim.list_extend({}, opts.args or {}),
    on_exit = function(_code, _signal)
      state.sclang = nil
      state.sclang_win = nil
    end,
  })
  local win_opts = { split = split or config.options.boot.split or "h" }
  state.sclang:start(win_opts)
  state.sclang_buf = state.sclang.buf.bufnr
  state.sclang_win = state.sclang.win_id
  state.sclang:send_line("s.options.numWireBufs = 128;")
  state.sclang:send_line("s.options.numAudioBusChannels = 2048;")
  state.sclang:send_line('s.options.device = "JACK";')

  local looper = config.options.boot.looper
  if looper and looper.enabled then
    local looper_file = vim.api.nvim_get_runtime_file("bootfiles/Looper.scd", false)[1]
    if looper_file then
      state.sclang:send_line(
        string.format(
          [[
s.waitForBoot {
  ~dirt = SuperDirt(2, s);
  ~numBuffers = %d;
  ~linput = %d;
  ~lname = "%s";
  ~path = "%s";
  ~pLevel = %s;
  ~rLevel = %s;
  ~latencyFineTuning = 0.04;
  ~debugMode = %s;
  "%s".load;
};
]],
          looper.num_buffers or 8,
          looper.default_input or 0,
          looper.default_name or "loop",
          looper.persist_path or "~/Music/Loops/",
          looper.p_level or 0.0,
          looper.r_level or 2.5,
          looper.debug_mode and "true" or "false",
          looper_file:gsub("\\", "\\\\"):gsub('"', '\\"')
        )
      )
    else
      notify.warn("Looper enabled but Looper.scd not found; falling back to normal boot")
      local file = vim.fn.expand(opts.file)
      state.sclang:send_line('"' .. file .. '".load;')
    end
  else
    local file = vim.fn.expand(opts.file)
    state.sclang:send_line('"' .. file .. '".load;')
  end
end

local function resolve_soundcard(opts)
  if opts.soundcard then
    return opts.soundcard
  end
  if state.soundcard then
    return state.soundcard
  end
  return nil
end

function M.sclang(opts, split, callback)
  if not opts.enabled then
    if callback then
      callback()
    end
    return
  end

  local card = resolve_soundcard(opts)

  if card then
    if opts.kill_jack then
      vim.fn.system("jack_control stop 2>/dev/null; true")
    end
    local ok = soundcard.launch_jackd(card)
    if not ok then
      notify.warn("Continuing without JACK; SuperCollider may not have audio")
    end
    if opts.pre_cmd then
      vim.fn.system(opts.pre_cmd)
    end
    start_sclang(opts, split)
    if callback then
      callback()
    end
    return
  end

  local cards = soundcard.parse_cards()
  if #cards == 0 then
    if opts.kill_jack then
      vim.fn.system("jack_control stop 2>/dev/null; true")
    end
    if opts.pre_cmd then
      vim.fn.system(opts.pre_cmd)
    end
    start_sclang(opts, split)
    if callback then
      callback()
    end
    return
  end

  soundcard.select(cards, function(selected)
    if not selected then
      notify.warn("No soundcard selected; launching without Jackd")
      if opts.pre_cmd then
        vim.fn.system(opts.pre_cmd)
      end
      start_sclang(opts, split)
      if callback then
        callback()
      end
      return
    end
    state.soundcard = selected
    if opts.kill_jack then
      vim.fn.system("jack_control stop 2>/dev/null; true")
    end
    local ok = soundcard.launch_jackd(selected)
    if not ok then
      notify.warn("Continuing without JACK; SuperCollider may not have audio")
    end
    if opts.pre_cmd then
      vim.fn.system(opts.pre_cmd)
    end
    start_sclang(opts, split)
    if callback then
      callback()
    end
  end)
end

return M
