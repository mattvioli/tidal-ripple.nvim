vim.g.mapleader = " "

-- Make the plugin source available on the runtimepath
vim.o.runtimepath = vim.o.runtimepath .. "," .. vim.fn.getcwd()

-- Locate plenary.nvim across common installation paths
local plenary_locs = {
  "/tmp/plenary.nvim",
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/core/opt/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/mini/start/plenary.nvim"),
}
for _, path in ipairs(plenary_locs) do
  if vim.fn.isdirectory(path) == 1 then
    vim.o.runtimepath = vim.o.runtimepath .. "," .. path
    break
  end
end
