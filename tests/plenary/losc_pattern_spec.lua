local Pattern = require("tidal.lib.losc.pattern")

describe("losc.pattern", function()
  describe("Pattern.escape", function()
    it("escapes literal characters", function()
      assert.equals("foo%.bar", Pattern.escape("foo.bar"))
      assert.equals("foo%+bar", Pattern.escape("foo+bar"))
      assert.equals("foo%$bar", Pattern.escape("foo$bar"))
      assert.equals("foo%(bar%)", Pattern.escape("foo(bar)"))
    end)

    it("converts * to .*", function()
      assert.equals("foo.*bar", Pattern.escape("foo*bar"))
    end)

    it("converts ? to .", function()
      assert.equals("foo.bar", Pattern.escape("foo?bar"))
    end)

    it("converts [ to [^", function()
      assert.equals("foo[^bar", Pattern.escape("foo[!bar"))
    end)

    it("converts ] to ]+", function()
      assert.equals("foo]+bar", Pattern.escape("foo]bar"))
    end)
  end)
end)
