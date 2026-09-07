local config = require("tidal.config")
local state = require("tidal.core.state")
local statusline = require("tidal.core.statusline")

describe("core.statusline", function()
  before_each(function()
    config.setup({})
    state.current_cps = nil
    state.current_cycle = nil
    state.current_bpm = nil
    state.current_time_sig_num = nil
    state.current_time_sig_denom = nil
  end)

  it("returns empty when disabled", function()
    config.setup({ statusline = { enabled = false } })
    assert.equals("", statusline.get_status())
  end)

  it("returns empty when cps or cycle missing", function()
    state.current_cps = 1.0
    assert.equals("", statusline.get_status())
    state.current_cps = nil
    state.current_cycle = 4
    assert.equals("", statusline.get_status())
  end)

  it("formats cps, cycle, bpm and timesig", function()
    state.current_cps = 0.56789
    state.current_cycle = 4.123
    state.current_bpm = 136
    state.current_time_sig_num = 4
    state.current_time_sig_denom = 4
    local status = statusline.get_status()
    assert.is_true(status:find("0%.568"), status)
    assert.is_true(status:find("4%.1"), status)
    assert.is_true(status:find("136"), status)
    assert.is_true(status:find("4/4"), status)
  end)

  it("falls back to -- for missing bpm", function()
    state.current_cps = 1.0
    state.current_cycle = 1.0
    local status = statusline.get_status()
    assert.is_true(status:find("--"), status)
  end)

  it("falls back to ?/? for missing timesig", function()
    state.current_cps = 1.0
    state.current_cycle = 1.0
    local status = statusline.get_status()
    assert.is_true(status:find("%?/%?"), status)
  end)

  it("returns empty for empty format", function()
    config.setup({ statusline = { format = "" } })
    state.current_cps = 1.0
    state.current_cycle = 1.0
    assert.equals("", statusline.get_status())
  end)
end)
