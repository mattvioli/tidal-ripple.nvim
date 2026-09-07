describe("completion.symbols", function()
  local symbols

  local function new_buf(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf
  end

  before_each(function()
    package.loaded["tidal.completion.symbols"] = nil
    symbols = require("tidal.completion.symbols")
  end)

  describe("scan_buffer", function()
    it("does not crash on invalid buffer", function()
      assert.is_nil(symbols.scan_buffer(999999))
    end)

    it("parses let-bound patterns", function()
      local buf = new_buf({
        'let bass = s "bd" * 4',
        'let hats = s "hh"',
        "d1 $ bass",
      })
      symbols.scan_buffer(buf)
      local all = symbols.get_all_symbols()
      assert.equals(2, #all)
      assert.equals("bass", all[1].word)
      assert.equals("hats", all[2].word)
      assert.equals("bd", symbols.get_bank_for_symbol("bass"))
      assert.equals("hh", symbols.get_bank_for_symbol("hats"))
    end)

    it("parses p-pattern definitions", function()
      local buf = new_buf({
        'p "drums" $ s "bd cp"',
        'd1 $ p "drums"',
      })
      symbols.scan_buffer(buf)
      local names = symbols.get_symbol_names()
      assert.are.same({ "drums" }, names)
    end)

    it("parses bare assignments", function()
      local buf = new_buf({
        'melody = s "808"',
      })
      symbols.scan_buffer(buf)
      local names = symbols.get_symbol_names()
      assert.are.same({ "melody" }, names)
      assert.equals("808", symbols.get_bank_for_symbol("melody"))
    end)

    it("ignores comments", function()
      local buf = new_buf({
        '-- let notASymbol = s "bd"',
        'd1 $ s "bd" -- let alsoNot = s "hh"',
      })
      symbols.scan_buffer(buf)
      assert.are.same({}, symbols.get_symbol_names())
    end)

    it("handles multi-line let blocks", function()
      local buf = new_buf({
        "let",
        '  bass = s "bd"',
        '  hats = s "hh"',
        "in d1 $ bass",
      })
      symbols.scan_buffer(buf)
      local names = symbols.get_symbol_names()
      table.sort(names)
      assert.are.same({ "bass", "hats" }, names)
    end)

    it("re-scans overwrites previous symbols", function()
      local buf = new_buf({
        'let a = s "bd"',
        'let b = s "hh"',
      })
      symbols.scan_buffer(buf)
      assert.equals(2, #symbols.get_all_symbols())

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'let c = s "cp"' })
      symbols.scan_buffer(buf)
      local names = symbols.get_symbol_names()
      assert.are.same({ "c" }, names)
    end)
  end)
end)
