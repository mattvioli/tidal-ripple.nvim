local parser = require("tidal.completion.parser")
local data = require("tidal.completion.data")

describe("completion.data", function()
  describe("data tables", function()
    it("control_params has no duplicate words", function()
      local seen = {}
      for _, p in ipairs(data.control_params) do
        assert.are_not.equals(true, seen[p.word], "duplicate param: " .. p.word)
        seen[p.word] = true
        if p.aliases then
          for _, a in ipairs(p.aliases) do
            assert.are_not.equals(true, seen[a], "duplicate alias: " .. a)
            seen[a] = true
          end
        end
      end
    end)

    it("pattern_functions has no duplicate words", function()
      local seen = {}
      for _, f in ipairs(data.pattern_functions) do
        assert.are_not.equals(true, seen[f.word], "duplicate function: " .. f.word)
        seen[f.word] = true
        if f.aliases then
          for _, a in ipairs(f.aliases) do
            assert.are_not.equals(true, seen[a], "duplicate alias: " .. a)
            seen[a] = true
          end
        end
      end
    end)

    it("orbit aliases cover d0 through d16", function()
      assert.equals(17, #data.orbit_aliases)
      assert.equals("d0", data.orbit_aliases[1].word)
      assert.equals("d16", data.orbit_aliases[17].word)
    end)
  end)

  describe("get_all_params", function()
    it("includes words and aliases", function()
      local params = data.get_all_params()
      assert.is_true(vim.tbl_contains(params, "s"))
      assert.is_true(vim.tbl_contains(params, "gain"))
      assert.is_true(vim.tbl_contains(params, "rel"))
      assert.is_true(vim.tbl_contains(params, "lpf"))
    end)
  end)

  describe("get_all_functions", function()
    it("includes words and aliases", function()
      local funcs = data.get_all_functions()
      assert.is_true(vim.tbl_contains(funcs, "slow"))
      assert.is_true(vim.tbl_contains(funcs, "rev"))
      assert.is_true(vim.tbl_contains(funcs, "rib"))
    end)
  end)

  describe("get_all_keywords", function()
    it("includes all word categories", function()
      local keys = data.get_all_keywords()
      assert.is_not_nil(keys.s)
      assert.is_not_nil(keys["sine"])
      assert.is_not_nil(keys.d1)
      assert.is_not_nil(keys.hush)
      assert.is_not_nil(keys.slow)
    end)

    it("marks aliases with alias_of", function()
      local keys = data.get_all_keywords()
      assert.equals("release", keys.rel.alias_of)
      assert.equals("cutoff", keys.lpf.alias_of)
    end)
  end)

  describe("parser integration", function()
    it("parser exposes is_ts_available", function()
      assert.is_boolean(parser.is_ts_available())
    end)
  end)
end)
