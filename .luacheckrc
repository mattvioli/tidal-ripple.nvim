-- luacheck configuration for tidal-ripple.nvim
--
-- Lints the plugin source and its test suite.
-- The plenary/busted test runner provides these extra globals:
--   describe, it, before_each, after_each, pending, assert

std = "luajit"

globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
  "pending",
  "assert",
  -- Module-level functions in core/taptempo.lua that intentionally use
  -- forward-referencing between one another (record_tap / record_subtap /
  -- redraw / activate).
  "record_tap",
  "record_subtap",
  "redraw",
  "activate",
}

-- The vendored losc library is third-party code.
exclude_files = {
  "lua/tidal/lib/losc/lib/struct.lua",
}

-- The vendored losc library intentionally feature-detects Lua 5.3's
-- string.pack / string.unpack (absent in the LuaJIT used by Neovim).
files["lua/tidal/lib/losc/serializer.lua"] = { ignore = { "143" } }
files["lua/tidal/lib/losc/types.lua"] = { ignore = { "143" } }

-- 212: unused argument (API shape: func(_, x))
-- 213: unused loop variable (common in callback loops)
-- 431: shadowing upvalue (common in test setup patterns)
-- 611: line too long (lenient in tests)
ignore = {
  "212",
  "213",
  "431",
  "611",
}