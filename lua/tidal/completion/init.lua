local parser = require("tidal.completion.parser")
local symbols = require("tidal.completion.symbols")
local config = require("tidal.config")
local notify = require("tidal.util.notify")

local M = {}

local notified = false
local debounce = nil

local function current_context()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local buf = vim.api.nvim_win_get_buf(0)
  return parser.get_context(buf, row, col)
end

local function prefix_len(ctx)
  if
    ctx.type == "sample"
    or ctx.type == "index"
    or ctx.type == "param_value"
    or ctx.type == "keyword"
    or ctx.type == "param"
    or ctx.type == "function"
  then
    return (ctx.prefix or ""):len()
  end
  return 0
end

local function should_autocomplete(ctx)
  if not ctx or not ctx.type then
    return false
  end
  if ctx.type == "empty" then
    return false
  end
  if ctx.type == "param" or ctx.type == "function" then
    return true
  end
  if ctx.type == "sample" or ctx.type == "index" or ctx.type == "param_value" then
    return (ctx.prefix or "") ~= ""
  end
  if ctx.type == "keyword" then
    return (ctx.prefix or ""):len() >= 1
  end
  return false
end

function M.complete(findstart, base)
  if findstart == 1 then
    local ctx = current_context()

    if not parser.is_ts_available() and not notified then
      notified = true
      notify.info("tidal-ripple autocomplete: nvim-treesitter with haskell parser recommended for best results")
    end

    local col = vim.fn.col(".") - 1
    local startcol = col - prefix_len(ctx)
    if startcol < 0 then
      startcol = 0
    end
    return startcol
  end

  local ctx = current_context()
  if base and base ~= "" then
    ctx.prefix = base
  end
  if not should_autocomplete(ctx) then
    return {}
  end
  return parser.get_completions(ctx)
end

local function trigger_omnifunc()
  if vim.fn.pumvisible() ~= 0 then
    return
  end
  local ctx = current_context()
  if not should_autocomplete(ctx) then
    return
  end
  if #parser.get_completions(ctx) == 0 then
    return
  end
  vim.schedule(function()
    if vim.fn.pumvisible() ~= 0 then
      return
    end
    local scheduled_ctx = current_context()
    if not should_autocomplete(scheduled_ctx) then
      return
    end
    if #parser.get_completions(scheduled_ctx) == 0 then
      return
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n", false)
  end)
end

local function popup()
  if debounce then
    debounce:stop()
  end
  debounce = vim.loop.new_timer()
  debounce:start(
    70,
    0,
    vim.schedule_wrap(function()
      debounce:stop()
      if vim.fn.pumvisible() ~= 0 then
        return
      end
      local ctx = current_context()
      if not should_autocomplete(ctx) then
        return
      end
      pcall(trigger_omnifunc)
    end)
  )
end

function M.setup()
  if not config.options.completion or config.options.completion.enabled ~= false then
    local conf = config.options.completion or {}
    local backend = conf.backend or "cmp"
    local use_cmp = backend == "cmp"

    local ok, cmp_mod = pcall(require, "tidal.completion.cmp")

    if use_cmp and ok and cmp_mod.register() then
      -- nvim-cmp backend.
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.tidal",
        callback = function(args)
          if vim.bo[args.buf].filetype == "haskell" then
            symbols.scan_buffer(args.buf)
          end
        end,
      })
      return
    end

    -- Fallback: pure omnifunc autocompletion.
    local opt = vim.o.completeopt
    for _, flag in ipairs({ "menuone", "noinsert", "noselect" }) do
      if not vim.tbl_contains(vim.split(opt, ","), flag) then
        vim.o.completeopt = opt == "" and flag or (opt .. "," .. flag)
        opt = vim.o.completeopt
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "haskell",
      callback = function(args)
        if vim.bo[args.buf].filetype == "haskell" then
          vim.bo[args.buf].omnifunc = "v:lua.require'tidal.completion'.complete"
          symbols.scan_buffer(args.buf)
        end
      end,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.tidal",
      callback = function(args)
        symbols.scan_buffer(args.buf)
      end,
    })

    vim.api.nvim_create_autocmd("TextChangedI", {
      pattern = "*.tidal",
      callback = popup,
    })
  end
end

return M
