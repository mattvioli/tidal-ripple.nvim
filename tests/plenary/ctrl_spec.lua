local ctrl = require("tidal.core.ctrl")
local config = require("tidal.config")

describe("core.ctrl", function()
  before_each(function()
    config.setup({})
    ctrl.reset()
  end)

  after_each(function()
    ctrl.reset()
  end)

  describe("dispatch value coercion", function()
    it("stores number values as-is", function()
      ctrl.dispatch({ address = "/ctrl", [1] = "amp", [2] = 0.5 })
      assert.equals(0.5, ctrl.get("amp"))
    end)

    it("converts numeric strings to numbers", function()
      ctrl.dispatch({ address = "/ctrl", [1] = "amp", [2] = "0.5" })
      assert.equals(0.5, ctrl.get("amp"))
    end)

    it("keeps non-numeric strings as strings", function()
      ctrl.dispatch({ address = "/ctrl", [1] = "meter", [2] = "peak" })
      assert.equals("peak", ctrl.get("meter"))
    end)

    it("ignores other types", function()
      ctrl.dispatch({ address = "/ctrl", [1] = "x", [2] = {} })
      assert.are.same({}, ctrl.get("x"))
    end)

    it("ignores messages with wrong address", function()
      ctrl.dispatch({ address = "/notctrl", [1] = "k", [2] = "v" })
      assert.is_nil(ctrl.get("k"))
    end)

    it("ignores messages without a key", function()
      assert.has_no.errors(function()
        ctrl.dispatch({ address = "/ctrl", [2] = "v" })
      end)
    end)
  end)

  describe("listeners", function()
    it("registers and removes listeners", function()
      local called = 0
      local cb = function()
        called = called + 1
      end
      ctrl.on_change("amp", cb)
      ctrl.remove_listener("amp", cb)
      ctrl.dispatch({ address = "/ctrl", [1] = "amp", [2] = 1 })
      vim.wait(50)
      assert.equals(0, called)
    end)
  end)
end)
