local api = require("tidal.api")
local config = require("tidal.config")
local message = require("tidal.core.message")
local notify = require("tidal.util.notify")
local toggle = require("tidal.core.toggle")

local Tidal = {}

local keymaps = {
  send_line = { callback = api.send_line, desc = "Send current line to tidal" },
  send_visual = {
    callback = api.send_visual,
    desc = "Send current visual selection to tidal",
  },
  send_block = { callback = api.send_block, desc = "Send current block to tidal" },
  send_node = { callback = api.send_node, desc = "Send current TS node to tidal" },
  send_silence = { callback = api.send_silence, desc = "Send 'd{count} silence' to tidal" },
  send_hush = { callback = api.send_hush, desc = "Send 'hush' to tidal" },
  show_meter = { callback = api.show_meter, desc = "Show SuperCollider meter window" },
  show_scope = { callback = api.show_scope, desc = "Show SuperCollider scope window" },
  show_tree = { callback = api.show_tree, desc = "Show SuperCollider node tree" },
  toggle_osc = { callback = api.toggle_osc, desc = "Toggle OSC listener" },
  toggle_visualizer = { callback = api.toggle_visualizer, desc = "Toggle visualizer floating window" },
  toggle_taptempo = { callback = api.toggle_taptempo, desc = "Toggle tap tempo mode" },
  looper_record = { callback = api.looper_record, desc = "Record loop on current orbit" },
  looper_overdub = { callback = api.looper_overdub, desc = "Overdub loop on current orbit" },
  looper_free = { callback = api.looper_free, desc = "Free loop buffer" },
  looper_free_all = { callback = api.looper_free_all, desc = "Free all loop buffers" },
  looper_mode_cycle = { callback = api.looper_cycle_mode, desc = "Cycle looper mode (replace/overdub)" },
  looper_persist = { callback = api.looper_persist, desc = "Persist loops to disk" },
  toggle_sample_browser = { callback = api.toggle_sample_browser, desc = "Toggle sample bank browser" },
  investigate_sample = { callback = api.investigate_sample, desc = "Investigate sample bank under cursor" },
  osc_mute = { callback = api.osc_mute, desc = "Mute orbit via OSC (count = orbit, default all)" },
  osc_unmute = { callback = api.osc_unmute, desc = "Unmute orbit via OSC (count = orbit, default all)" },
  osc_solo = { callback = api.osc_solo, desc = "Solo orbit via OSC (count = orbit, default all muted)" },
  osc_unsolo = { callback = api.osc_unsolo, desc = "Unsolo orbit via OSC (count = orbit, default all)" },
  osc_hush = { callback = api.osc_hush, desc = "Hush via OSC" },
}

local function setup_user_commands()
  vim.api.nvim_create_user_command("TidalLaunch", function()
    api.launch_tidal(config.options.boot)
  end, { desc = "Launch Tidal instance" })

  vim.api.nvim_create_user_command("TidalQuit", api.exit_tidal, { desc = "Quit Tidal instance" })

  vim.api.nvim_create_user_command("TidalToggle", toggle.toggle_ghci, { desc = "Toggle Tidal REPL window" })

  vim.api.nvim_create_user_command("TidalHush", api.send_hush, { desc = "Hush all Tidal patterns" })

  vim.api.nvim_create_user_command("TidalSilence", function(opts)
    local n = tonumber(opts.args) or vim.v.count
    message.tidal.send_line(string.format("d%d silence", n))
  end, { nargs = "?", desc = "Silence a Tidal pattern (default: d0)" })

  vim.api.nvim_create_user_command("TidalOSCToggle", api.toggle_osc, { desc = "Toggle OSC listener" })
  vim.api.nvim_create_user_command("TidalVisualizerToggle", api.toggle_visualizer, {
    desc = "Toggle visualizer floating window",
  })
  vim.api.nvim_create_user_command("TidalTapTempo", api.toggle_taptempo, { desc = "Toggle tap tempo mode" })
  vim.api.nvim_create_user_command("TidalTapTempoReset", api.reset_taps, { desc = "Reset tap tempo history" })

  vim.api.nvim_create_user_command("TidalLooperRecord", api.looper_record, {
    desc = "Record loop (count = orbit, default d1)",
  })
  vim.api.nvim_create_user_command("TidalLooperOverdub", api.looper_overdub, {
    desc = "Overdub loop (count = orbit, default d1)",
  })
  vim.api.nvim_create_user_command("TidalLooperFree", api.looper_free, {
    desc = "Free loop buffer (count = buffer number)",
  })
  vim.api.nvim_create_user_command("TidalLooperFreeAll", api.looper_free_all, { desc = "Free all loop buffers" })
  vim.api.nvim_create_user_command("TidalLooperPersist", api.looper_persist, {
    desc = "Persist loops to disk (count = name)",
  })
  vim.api.nvim_create_user_command("TidalLooperMode", function(opts)
    api.looper_set_mode(opts.args)
  end, {
    nargs = 1,
    complete = "customlist,v:lua.require'tidal.api'.looper_mode_complete",
    desc = "Set looper mode: replace|overdub",
  })

  vim.api.nvim_create_user_command("TidalLooperInput", function(opts)
    api.looper_set_input(tonumber(opts.args))
  end, { nargs = 1, desc = "Set looper input port" })

  vim.api.nvim_create_user_command("TidalSampleBrowser", api.toggle_sample_browser, {
    desc = "Toggle sample bank browser",
  })
  vim.api.nvim_create_user_command("TidalSampleInvestigate", api.investigate_sample, {
    desc = "Investigate sample bank under cursor",
  })

  vim.api.nvim_create_user_command("TidalMute", function(opts)
    api.osc_mute(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Mute orbit via OSC (arg = orbit/pattern name, default all)" })
  vim.api.nvim_create_user_command("TidalUnmute", function(opts)
    api.osc_unmute(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Unmute orbit via OSC (arg = orbit/pattern name, default all)" })
  vim.api.nvim_create_user_command("TidalSolo", function(opts)
    api.osc_solo(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Solo orbit via OSC (arg = orbit/pattern name, default all)" })
  vim.api.nvim_create_user_command("TidalUnsolo", function(opts)
    api.osc_unsolo(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Unsolo orbit via OSC (arg = orbit/pattern name, default all)" })
  vim.api.nvim_create_user_command("TidalCtrlSend", function(opts)
    local key, value = opts.args:match("^(%S+)%s+(%S+)$")
    if key then
      local v = tonumber(value) or value
      api.ctrl_send(key, v)
    else
      notify.warn("Usage: TidalCtrlSend <key> <value>")
    end
  end, { nargs = "+", desc = "Send a /ctrl value to Tidal" })
  vim.api.nvim_create_user_command("TidalCtrlList", api.ctrl_list, { desc = "List received /ctrl values" })
  vim.api.nvim_create_user_command("TidalCtrlClear", api.ctrl_clear, { desc = "Clear received /ctrl values" })
end

local function setup_autocmds()
  vim.api.nvim_create_augroup("TidalRipple", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = "TidalRipple",
    pattern = { "*.tidal" },
    callback = function()
      if config.options.auto_launch then
        api.ensure_launched()
      end
      for name, mapping in pairs(config.options.mappings or {}) do
        if mapping then
          local command = keymaps[name]
          vim.keymap.set(mapping.mode, mapping.key, command.callback, { buffer = true, desc = command.desc })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "Filetype" }, {
    group = "TidalRipple",
    pattern = { "supercollider" },
    callback = function()
      for name, mapping in pairs(config.options.mappings or {}) do
        if mapping then
          local command = keymaps[name]
          vim.keymap.set(mapping.mode, mapping.key, command.callback, { buffer = true, desc = command.desc })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = "TidalRipple",
    callback = function()
      require("tidal.core.taptempo").deactivate()
      api.exit_tidal()
    end,
  })
end

local MIN_VERSION = "0.10.0"

local function setup_highlights()
  vim.api.nvim_set_hl(0, "TidalRippleTapHead", { fg = "#51CF66", bold = true, default = true })
  vim.api.nvim_set_hl(0, "TidalRippleTapMid", { fg = "#2B8A3E", bold = true, default = true })
  vim.api.nvim_set_hl(0, "TidalRippleTapTail", { fg = "#1C5E2D", default = true })
end

function Tidal.setup(options)
  if vim.fn.has("nvim-" .. MIN_VERSION) == 0 then
    notify.error("tidal-ripple.nvim requires nvim >= " .. MIN_VERSION)
    return
  end
  config.setup(options)
  setup_highlights()
  setup_autocmds()
  setup_user_commands()
  require("tidal.completion").setup()
end

Tidal.api = api

return Tidal
