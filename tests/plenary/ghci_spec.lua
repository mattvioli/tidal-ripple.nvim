local Ghci = require("tidal.util.repl.ghci")

describe("util.repl.ghci", function()
  describe("send_multiline", function()
    it("wraps lines in a Haskell multiline block", function()
      local obj = setmetatable({}, { __index = Ghci })
      local sent = nil
      obj.send = function(_, text)
        sent = text
        return obj
      end
      obj:send_multiline({ 'd1 $ s "bd"', 'd2 $ s "hh"' })
      assert.equals(':{\nd1 $ s "bd"\nd2 $ s "hh"\n:}\n', sent)
    end)

    it("handles a single line", function()
      local obj = setmetatable({}, { __index = Ghci })
      local sent = nil
      obj.send = function(_, text)
        sent = text
        return obj
      end
      obj:send_multiline({ 'd1 $ s "bd"' })
      assert.equals(':{\nd1 $ s "bd"\n:}\n', sent)
    end)

    it("handles an empty line table", function()
      local obj = setmetatable({}, { __index = Ghci })
      local sent = nil
      obj.send = function(_, text)
        sent = text
        return obj
      end
      obj:send_multiline({})
      assert.equals(":{\n\n:}\n", sent)
    end)
  end)
end)
