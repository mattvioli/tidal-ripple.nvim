local boot = require("tidal.core.boot")
local message = require("tidal.core.message")
local notify = require("tidal.util.notify")
local select = require("tidal.util.select")
local state = require("tidal.core.state")
local util = require("tidal.util")
local config = require("tidal.config")

local M = {}

local function parse_orbit(text)
  return tonumber(text:match("^d(%d+)"))
end

local function enqueue_playhead(start_pos, finish_pos, text)
  local bufnr = vim.api.nvim_get_current_buf()
  local orbit = text and parse_orbit(text)
  if config.options.playhead.enabled then
    require("tidal.core.playhead").enqueue(bufnr, finish_pos[1], finish_pos[1], orbit)
  end
  if config.options.event_highlight.enabled and orbit then
    require("tidal.core.event_highlight").track(bufnr, finish_pos[1], orbit)
  end
end

function M.ensure_launched()
  if state.launched then
    return
  end
  if state.launching then
    return
  end
  state.launching = true
  local opts = config.options.boot
  local current_win = vim.api.nvim_get_current_win()
  if opts.tidal.enabled then
    boot.tidal(opts.tidal, opts.split)
  end
  if opts.sclang.enabled then
    local sclang_split = opts.tidal.enabled and opts.split == "h" and "v" or opts.split
    boot.sclang(opts.sclang, sclang_split, function()
      vim.api.nvim_set_current_win(current_win)
      state.launched = true
      state.launching = false
      if config.options.osc.enabled then
        require("tidal.core.osc").start()
      end
    end)
  else
    vim.api.nvim_set_current_win(current_win)
    state.launched = true
    state.launching = false
    if config.options.osc.enabled then
      require("tidal.core.osc").start()
    end
  end
end

function M.launch_tidal(args)
  local current_win = vim.api.nvim_get_current_win()
  if state.launched then
    notify.warn("Tidal is already running")
    return
  end
  if state.launching then
    return
  end
  state.launching = true
  if args.tidal.enabled then
    boot.tidal(args.tidal, args.split)
  end
  if args.sclang.enabled then
    local sclang_split = args.tidal.enabled and args.split == "h" and "v" or args.split
    boot.sclang(args.sclang, sclang_split, function()
      vim.api.nvim_set_current_win(current_win)
      state.launched = true
      state.launching = false
      if config.options.osc.enabled then
        require("tidal.core.osc").start()
      end
    end)
  else
    vim.api.nvim_set_current_win(current_win)
    state.launched = true
    state.launching = false
    if config.options.osc.enabled then
      require("tidal.core.osc").start()
    end
  end
end

function M.exit_tidal()
  if not state.launched then
    notify.warn("Tidal is not running. Launch with ':TidalLaunch'")
    return
  end
  for _, proc in ipairs({ state.ghci, state.sclang }) do
    if proc then
      proc:exit()
    end
  end
  state.launched = false
  state.launching = false
  state.ghci = nil
  state.ghci_win = nil
  state.ghci_buf = nil
  state.sclang = nil
  state.sclang_win = nil
  state.sclang_buf = nil

  require("tidal.core.osc").stop()
  require("tidal.core.osc_out").stop()
  require("tidal.core.playhead").clear()
  require("tidal.core.event_highlight").clear()
end

local function ft_to_repl()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  if ft == "supercollider" then
    return message.sclang
  end
  return message.tidal
end

function M.send(text)
  local repl = ft_to_repl()
  if repl then
    repl.send_line(text)
  end
end

function M.send_silence()
  local orbit = vim.v.count
  require("tidal.core.playhead").clear(orbit)
  require("tidal.core.event_highlight").clear(orbit)
  message.tidal.send_line(string.format("d%d silence", orbit))
end

function M.send_hush()
  require("tidal.core.playhead").clear()
  require("tidal.core.event_highlight").clear()
  message.tidal.send_line("hush")
end

function M.send_multiline(lines)
  local repl = ft_to_repl()
  if repl then
    repl.send_multiline(lines)
  end
end

function M.send_line()
  if config.options.auto_launch then
    M.ensure_launched()
  end
  local line = select.get_current_line()
  local text = line.lines[1]
  if #text > 0 then
    require("tidal.core.highlight").apply_highlight(line.start, line.finish)
    enqueue_playhead(line.start, line.finish, text)
    local repl = ft_to_repl()
    if repl then
      repl.send_line(text)
    end
  end
end

function M.send_visual()
  if config.options.auto_launch then
    M.ensure_launched()
  end
  local visual = select.get_visual()
  if visual then
    require("tidal.core.highlight").apply_highlight(visual.start, visual.finish)
    enqueue_playhead(visual.start, visual.finish, visual.lines[#visual.lines])
    local repl = ft_to_repl()
    if repl then
      repl.send_multiline(visual.lines)
    end
  end
end

function M.send_block()
  if config.options.auto_launch then
    M.ensure_launched()
  end
  if util.is_empty(vim.api.nvim_get_current_line()) then
    return
  end
  local block = select.get_block()
  require("tidal.core.highlight").apply_highlight(block.start, block.finish)
  enqueue_playhead(block.start, block.finish, block.lines[#block.lines])
  local repl = ft_to_repl()
  if repl then
    repl.send_multiline(block.lines)
  end
end

function M.send_node()
  if config.options.auto_launch then
    M.ensure_launched()
  end
  local block = select.get_node()
  if block then
    require("tidal.core.highlight").apply_highlight(block.start, block.finish)
    enqueue_playhead(block.start, block.finish, block.lines[#block.lines])
    local repl = ft_to_repl()
    if repl then
      repl.send_multiline(block.lines)
    end
  end
end

function M.show_meter()
  if state.sclang and state.sclang:is_running() then
    state.sclang:send_line("s.meter")
  end
end

function M.show_scope()
  if state.sclang and state.sclang:is_running() then
    state.sclang:send_line("s.scope")
  end
end

function M.show_tree()
  if state.sclang and state.sclang:is_running() then
    state.sclang:send_line("s.plotTree")
  end
end

function M.start_osc()
  require("tidal.core.osc").start()
end

function M.stop_osc()
  require("tidal.core.osc").stop()
  require("tidal.core.playhead").clear()
  require("tidal.core.event_highlight").clear()
end

function M.toggle_visualizer()
  require("tidal.core.visualizer").toggle()
end

function M.toggle_osc()
  local osc = require("tidal.core.osc")
  if osc.is_running() then
    M.stop_osc()
  else
    M.start_osc()
  end
end

function M.toggle_taptempo()
  require("tidal.core.taptempo").toggle()
end

function M.reset_taps()
  require("tidal.core.taptempo").reset()
end

-- OSC output (Tidal port 6010)

local function normalize_pattern(arg)
  if type(arg) == "string" then
    local n = tonumber(arg)
    if n then
      return n
    end
  end
  return arg
end

function M.osc_mute(pattern)
  local osc_out = require("tidal.core.osc_out")
  if pattern then
    osc_out.mute(normalize_pattern(pattern))
  else
    local orbit = vim.v.count
    if orbit > 0 then
      osc_out.mute(orbit)
    else
      osc_out.mute()
    end
  end
end

function M.osc_unmute(pattern)
  local osc_out = require("tidal.core.osc_out")
  if pattern then
    osc_out.unmute(normalize_pattern(pattern))
  else
    local orbit = vim.v.count
    if orbit > 0 then
      osc_out.unmute(orbit)
    else
      osc_out.unmute()
    end
  end
end

function M.osc_solo(pattern)
  local osc_out = require("tidal.core.osc_out")
  if pattern then
    osc_out.solo(normalize_pattern(pattern))
  else
    local orbit = vim.v.count
    if orbit > 0 then
      osc_out.solo(orbit)
    else
      osc_out.solo()
    end
  end
end

function M.osc_unsolo(pattern)
  local osc_out = require("tidal.core.osc_out")
  if pattern then
    osc_out.unsolo(normalize_pattern(pattern))
  else
    local orbit = vim.v.count
    if orbit > 0 then
      osc_out.unsolo(orbit)
    else
      osc_out.unsolo()
    end
  end
end

function M.osc_hush()
  require("tidal.core.playhead").clear()
  require("tidal.core.event_highlight").clear()
  require("tidal.core.osc_out").hush()
end

-- MIDI controller (/ctrl) API

function M.ctrl_get(key)
  return require("tidal.core.ctrl").get(key)
end

function M.ctrl_get_all()
  return require("tidal.core.ctrl").get_all()
end

function M.ctrl_listen(key, callback)
  require("tidal.core.ctrl").on_change(key, callback)
end

function M.ctrl_send(key, value)
  require("tidal.core.osc_out").send_ctrl(key, value)
end

function M.ctrl_list()
  local values = require("tidal.core.ctrl").get_all()
  local keys = vim.tbl_keys(values)
  if #keys == 0 then
    notify.info("No /ctrl values received yet")
    return
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    print(string.format("%s = %s", k, tostring(values[k])))
  end
end

function M.ctrl_clear()
  require("tidal.core.ctrl").reset()
  notify.info("Cleared /ctrl values")
end

-- Looper API

function M.looper_record()
  local orbit = vim.v.count > 0 and vim.v.count or 1
  message.tidal.send_line(string.format('d%d $ s "rlooper"', orbit))
end

function M.looper_overdub()
  local orbit = vim.v.count > 0 and vim.v.count or 1
  message.tidal.send_line(string.format('d%d $ s "olooper"', orbit))
end

function M.looper_free()
  local buf = vim.v.count
  if buf > 0 then
    message.tidal.send_line(string.format('once $ s "freeLoops" # n "%d"', buf))
  else
    M.looper_free_all()
  end
end

function M.looper_free_all()
  message.tidal.send_line('once $ s "freeLoops"')
end

function M.looper_set_mode(mode)
  if mode == "overdub" then
    if state.sclang and state.sclang:is_running() then
      state.sclang:send_line("~pLevel = 1.0;")
    end
    config.options.boot.looper.p_level = 1.0
  else
    if state.sclang and state.sclang:is_running() then
      state.sclang:send_line("~pLevel = 0.0;")
    end
    config.options.boot.looper.p_level = 0.0
  end
end

function M.looper_cycle_mode()
  local current = config.options.boot.looper.p_level
  if current and current > 0.5 then
    M.looper_set_mode("replace")
    notify.info("Looper mode: replace")
  else
    M.looper_set_mode("overdub")
    notify.info("Looper mode: overdub")
  end
end

function M.looper_persist()
  local name = vim.v.count > 0 and tostring(vim.v.count) or config.options.boot.looper.default_name or "loop"
  message.tidal.send_line(string.format('once $ s "persistLoops" # lname "%s"', name))
end

function M.looper_set_input(port)
  port = port or config.options.boot.looper.default_input or 0
  if state.sclang and state.sclang:is_running() then
    state.sclang:send_line(string.format("~linput = %d;", port))
  end
  config.options.boot.looper.default_input = port
end

function M.looper_mode_complete(lead, _line, _pos)
  local modes = { "replace", "overdub" }
  local matches = {}
  for _, mode in ipairs(modes) do
    if mode:find(lead) == 1 then
      table.insert(matches, mode)
    end
  end
  return matches
end

function M.toggle_sample_browser()
  require("tidal.core.sample_browser").toggle()
end

function M.investigate_sample()
  require("tidal.core.sample_browser").investigate()
end

return M
