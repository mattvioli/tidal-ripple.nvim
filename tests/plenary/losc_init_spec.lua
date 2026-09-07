local losc = require("tidal.lib.losc")

describe("losc.init", function()
  local function new_plugin(val)
    return losc.new(val)
  end

  describe("losc.new_message", function()
    it("wraps Message.new", function()
      local m = losc.new_message("dirt/play")
      assert.equals("/dirt/play", m:address())
    end)
  end)

  describe("losc.new_bundle", function()
    it("wraps Bundle.new", function()
      local Timetag = require("tidal.lib.losc.timetag")
      local b = losc.new_bundle(Timetag.new_raw(100, 0))
      assert.is_not_nil(b.content.timetag)
    end)
  end)

  describe("handler management", function()
    it("adds and removes wildcard handlers", function()
      local p = new_plugin()
      local cb = function() end
      p:add_handler("/test", cb)
      p:remove_handler("/test", cb)
      p:remove_all()
    end)

    it("clears all handlers", function()
      local p = new_plugin()
      p:add_handler("/a", function() end)
      p:add_handler("/b", function() end)
      p:remove_all()
    end)
  end)
end)
