local util = require("tidal.util")

describe("util", function()
  describe("is_empty", function()
    it("returns true for nil", function()
      assert.is_true(util.is_empty(nil))
    end)

    it("returns true for empty string", function()
      assert.is_true(util.is_empty(""))
    end)

    it("returns false for non-empty string", function()
      assert.is_false(util.is_empty("hi"))
    end)
  end)
end)
