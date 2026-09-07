local mininotation = require("tidal.completion.mininotation")

describe("mininotation", function()
  describe("get_context", function()
    it("returns empty for nil/empty string", function()
      assert.are.same({ type = "empty" }, mininotation.get_context(nil))
      assert.are.same({ type = "empty" }, mininotation.get_context(""))
    end)

    it("classifies a word", function()
      local ctx = mininotation.get_context("bd")
      assert.equals("word", ctx.type)
      assert.equals("bd", ctx.value)
    end)

    it("classifies a number", function()
      local ctx = mininotation.get_context("3")
      assert.equals("number", ctx.type)
      assert.equals("3", ctx.value)
    end)

    it("classifies a rest", function()
      local ctx = mininotation.get_context("~")
      assert.equals("rest", ctx.type)
    end)

    it("classifies a colon as index context with sample", function()
      local ctx = mininotation.get_context("bd:3", 3)
      assert.equals("index", ctx.type)
      assert.equals("bd", ctx.sample)
    end)

    it("classifies modifiers", function()
      local ctx = mininotation.get_context("bd*2", 3)
      assert.equals("modifier", ctx.type)
      assert.equals("repeat", ctx.operator)
    end)

    it("classifies symbols", function()
      local ctx = mininotation.get_context("[", 1)
      assert.equals("symbol", ctx.type)
    end)

    it("classifies whitespace", function()
      local ctx = mininotation.get_context("bd hh", 3)
      assert.equals("whitespace", ctx.type)
    end)
  end)

  describe("extract_sample_names", function()
    it("extracts unique sample names", function()
      local names = mininotation.extract_sample_names("bd [cp bd] <hh>")
      for _, n in ipairs(names) do
        assert.is_true(n == "bd" or n == "cp" or n == "hh")
      end
      assert.equals(3, #names)
    end)

    it("returns empty for nil", function()
      assert.are.same({}, mininotation.extract_sample_names(nil))
    end)

    it("returns empty for empty string", function()
      assert.are.same({}, mininotation.extract_sample_names(""))
    end)
  end)

  describe("extract_sample_indices", function()
    it("extracts colons with values", function()
      local indices = mininotation.extract_sample_indices("bd:3 cp:5")
      assert.are.same({ "3", "5" }, indices)
    end)

    it("extracts bare numbers", function()
      local indices = mininotation.extract_sample_indices('d1 $ s "bd" # n "0 1 2"')
      assert.are.same({ 0, 1, 2 }, indices)
    end)
  end)
end)
