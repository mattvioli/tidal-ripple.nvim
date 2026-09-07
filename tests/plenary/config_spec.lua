local config = require("tidal.config")

describe("config", function()
  describe("defaults", function()
    it("has sane boot defaults", function()
      assert.is_true(config.options.boot.tidal.enabled)
      assert.equals("ghci", config.options.boot.tidal.cmd)
      assert.are.same({ "-v0" }, config.options.boot.tidal.args)
      assert.is_true(config.options.boot.sclang.enabled)
      assert.equals("sclang", config.options.boot.sclang.cmd)
      assert.is_false(config.options.boot.looper.enabled)
      assert.equals("h", config.options.boot.split)
    end)

    it("has osc defaults", function()
      assert.equals(5050, config.options.osc.port)
      assert.equals(6010, config.options.osc.tidal_port)
      assert.is_true(config.options.osc.enabled)
    end)

    it("has all mappings", function()
      local names = {
        "send_line",
        "send_visual",
        "send_block",
        "send_node",
        "send_silence",
        "send_hush",
        "show_meter",
        "show_scope",
        "show_tree",
        "toggle_osc",
        "toggle_visualizer",
        "toggle_taptempo",
        "looper_record",
        "looper_overdub",
        "looper_free",
        "looper_free_all",
        "looper_mode_cycle",
        "looper_persist",
        "toggle_sample_browser",
        "investigate_sample",
        "osc_mute",
        "osc_unmute",
        "osc_solo",
        "osc_unsolo",
        "osc_hush",
      }
      for _, n in ipairs(names) do
        assert.is_not_nil(config.options.mappings[n], "missing mapping: " .. n)
      end
    end)

    it("has taptempo defaults", function()
      assert.equals(2, config.options.taptempo.min_taps)
      assert.equals(16, config.options.taptempo.max_taps)
      assert.equals(0.3, config.options.taptempo.outlier_threshold)
      assert.equals(1000, config.options.taptempo.idle_ms)
    end)

    it("has visualizer defaults", function()
      assert.equals(60, config.options.visualizer.width)
      assert.equals(12, config.options.visualizer.height)
      assert.equals(8, #config.options.visualizer.palette)
    end)
  end)

  describe("setup", function()
    it("deep-merges user options over defaults", function()
      config.setup({
        osc = { port = 9999 },
        taptempo = { min_taps = 5 },
      })
      assert.equals(9999, config.options.osc.port)
      assert.equals(6010, config.options.osc.tidal_port, "tidal_port should survive partial override")
      assert.equals(5, config.options.taptempo.min_taps)
      config.setup({}) -- restore defaults for later tests
    end)

    it("accepts nil options", function()
      config.setup(nil)
      assert.is_not_nil(config.options)
    end)
  end)
end)
