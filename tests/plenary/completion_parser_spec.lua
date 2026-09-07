local parser = require("tidal.completion.parser")

describe("completion.parser", function()
  local buf = nil

  local function set_lines(lines)
    if buf then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local function ctx(row, col)
    return parser.get_context(buf, row, col)
  end

  describe("get_context", function()
    it("returns empty for empty line", function()
      set_lines({ "" })
      assert.equals("empty", ctx(1, 1).type)
    end)

    it("detects sample context inside open s string", function()
      set_lines({ 'd1 $ s "bd' })
      local c = ctx(1, 10)
      assert.equals("sample", c.type)
      assert.equals("s", c.param)
      assert.equals("bd", c.prefix)
    end)

    it("detects index context inside open n string with bank lookup", function()
      set_lines({ 'd1 $ s "bd" # n "3' })
      local c = ctx(1, 18)
      assert.equals("index", c.type)
      assert.equals("n", c.param)
      assert.equals("bd", c.bank)
      assert.equals("3", c.prefix)
    end)

    it("detects param context after #", function()
      set_lines({ 'd1 $ s "bd" # g' })
      local c = ctx(1, 15)
      assert.equals("param", c.type)
      assert.equals("g", c.prefix)
    end)

    it("detects function context after $", function()
      set_lines({ 'd1 $ s "bd" # delay $ re' })
      local c = ctx(1, 23)
      assert.equals("function", c.type)
      assert.equals("re", c.prefix)
    end)

    it("detects keyword context for bare identifiers", function()
      set_lines({ "re" })
      local c = ctx(1, 3)
      assert.equals("keyword", c.type)
      assert.equals("re", c.prefix)
    end)
  end)

  describe("get_completions", function()
    it("returns empty for nil/empty context", function()
      assert.are.same({}, parser.get_completions(nil))
      assert.are.same({}, parser.get_completions({ type = "empty" }))
    end)

    it("completes sample banks with prefix", function()
      local comps = parser.get_completions({ type = "sample", prefix = "bd" })
      local found = false
      for _, c in ipairs(comps) do
        assert.is_true(c.word:lower():find("bd", 1, true) == 1)
        if c.word == "bd" then
          found = true
        end
      end
      assert.is_true(found, "expected 'bd' in sample completions")
    end)

    it("completes index context with 0-255 range", function()
      local comps = parser.get_completions({ type = "index", prefix = "", bank = nil })
      assert.equals(256, #comps)
      assert.equals("0", comps[1].word)
      assert.equals("255", comps[256].word)
    end)

    it("filters index completions by prefix", function()
      local comps = parser.get_completions({ type = "index", prefix = "3", bank = nil })
      for _, c in ipairs(comps) do
        assert.is_true(c.word:find("^3"))
      end
      assert.is_true(#comps > 0)
    end)

    it("completes params with aliases", function()
      local comps = parser.get_completions({ type = "param", prefix = "" })
      assert.is_true(#comps > 0)
      local seen_sound, seen_rel = false, false
      for _, c in ipairs(comps) do
        if c.word == "s" then
          seen_sound = true
        end
        if c.word == "rel" then
          seen_rel = true
        end
      end
      assert.is_true(seen_sound, "expected 's' param")
      assert.is_true(seen_rel, "expected alias 'rel'")
    end)

    it("prefix-filters param completions", function()
      local comps = parser.get_completions({ type = "param", prefix = "ga" })
      for _, c in ipairs(comps) do
        assert.is_true(c.word:lower():find("^ga"))
      end
      assert.is_true(#comps > 0)
    end)

    it("completes functions with dedup", function()
      local comps = parser.get_completions({ type = "function", prefix = "" })
      assert.is_true(#comps > 0)
      local seen = {}
      for _, c in ipairs(comps) do
        assert.is_not_nil(c.word)
        assert.are_not.equals(true, seen[c.word], "dup: " .. c.word)
        seen[c.word] = true
      end
    end)

    it("completes keywords with dedup", function()
      local comps = parser.get_completions({ type = "keyword", prefix = "s" })
      for _, c in ipairs(comps) do
        assert.is_true(c.word:lower():find("^s"))
      end
      local seen = {}
      for _, c in ipairs(comps) do
        assert.are_not.equals(true, seen[c.word], "dup: " .. c.word)
        seen[c.word] = true
      end
    end)

    it("returns empty for unknown context type", function()
      assert.are.same({}, parser.get_completions({ type = "string", prefix = "x" }))
    end)
  end)
end)
