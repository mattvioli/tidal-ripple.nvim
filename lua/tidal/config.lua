local M = {}

local defaults = {
  boot = {
    tidal = {
      cmd = "ghci",
      args = { "-v0" },
      file = vim.api.nvim_get_runtime_file("bootfiles/BootTidal.hs", false)[1],
      enabled = true,
      osc_target = {
        enabled = true,
        port = 5050,
        address = "127.0.0.1",
        latency = 0.2,
      },
    },
    sclang = {
      cmd = "sclang",
      args = {},
      file = vim.api.nvim_get_runtime_file("bootfiles/BootSuperDirt.scd", false)[1],
      enabled = true,
      kill_jack = true,
      soundcard = nil,
      pre_cmd = nil,
    },
    looper = {
      enabled = false,
      num_buffers = 8,
      p_level = 0.0,
      r_level = 2.5,
      default_input = 0,
      default_name = "loop",
      persist_path = "~/Music/Loops/",
      debug_mode = false,
    },
    split = "h",
  },
  mappings = {
    send_line = { mode = { "i", "n" }, key = "<S-CR>" },
    send_visual = { mode = { "x" }, key = "<S-CR>" },
    send_block = { mode = { "i", "n", "x" }, key = "<M-CR>" },
    send_node = { mode = "n", key = "<leader><CR>" },
    send_silence = { mode = "n", key = "<leader>d" },
    send_hush = { mode = "n", key = "<leader><Esc>" },
    show_meter = { mode = { "n", "i", "x" }, key = "<F1>" },
    show_scope = { mode = { "n", "i", "x" }, key = "<F2>" },
    show_tree = { mode = { "n", "i", "x" }, key = "<F3>" },
    toggle_osc = { mode = "n", key = "<leader>o" },
    toggle_visualizer = { mode = "n", key = "<leader>v" },
    looper_record = { mode = "n", key = "<leader>lr" },
    looper_overdub = { mode = "n", key = "<leader>lo" },
    looper_free = { mode = "n", key = "<leader>lf" },
    looper_free_all = { mode = "n", key = "<leader>lF" },
    looper_mode_cycle = { mode = "n", key = "<leader>lm" },
    looper_persist = { mode = "n", key = "<leader>lp" },
    toggle_taptempo = { mode = "n", key = "<leader>t" },
    toggle_sample_browser = { mode = "n", key = "<leader>a" },
    investigate_sample = { mode = "n", key = "<leader>i" },
    osc_mute = { mode = "n", key = "<leader>m" },
    osc_unmute = { mode = "n", key = "<leader>u" },
    osc_solo = { mode = "n", key = "<leader>s" },
    osc_unsolo = { mode = "n", key = "<leader>S" },
    osc_hush = { mode = "n", key = "<leader>h" },
  },
  selection_highlight = {
    highlight = { link = "IncSearch" },
    timeout = 150,
  },
  osc = {
    port = 5050,
    tidal_port = 6010,
    enabled = true,
    debug = false,
    ctrl_debug = false,
  },
  event_highlight = {
    enabled = true,
    highlight = { link = "TidalRippleEvent" },
    fade_ms = 400,
  },
  playhead = {
    enabled = true,
    highlight = { link = "TidalRipplePlayhead" },
  },
  statusline = {
    enabled = true,
    format = "♩ {cps} CPS | c.{cycle}",
  },
  visualizer = {
    width = 60,
    height = 12,
    border = "single",
    refresh_interval_ms = 33,
    grid = {
      divisions = 4,
      total_cycles = 1,
      chars_per_beat = 8,
    },
    palette = {
      "#FF6B6B",
      "#51CF66",
      "#FFD43B",
      "#339AF0",
      "#CC5DE8",
      "#20C997",
      "#F06595",
      "#FF922B",
    },
    max_orbits = 8,
    max_events_per_orbit = 4,
  },
  sample_browser = {
    width_ratio = 0.33,
    border = "single",
  },
  auto_launch = true,
  completion = {
    enabled = true,
    backend = "cmp",
    source_name = "tidal",
  },
  taptempo = {
    min_taps = 2,
    max_taps = 16,
    outlier_threshold = 0.3,
    exit_factor = 3.0,
    idle_ms = 1000,
    popup = {
      width = 22,
      height = 16,
      border = "single",
      flash_ms = 150,
      refresh_ms = 50,
      anim_width = 12,
      anim_height = 3,
    },
  },
}

M.options = defaults

M.namespace = vim.api.nvim_create_namespace("TidalRipple")
M.playhead_ns = vim.api.nvim_create_namespace("TidalRipplePlayhead")

vim.api.nvim_set_hl(0, "TidalRipplePlayhead", { link = "CursorLine" })
vim.api.nvim_set_hl(0, "TidalRippleFlash", { link = "Search" })
vim.api.nvim_set_hl(0, "TidalRippleEvent", { link = "IncSearch" })

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
