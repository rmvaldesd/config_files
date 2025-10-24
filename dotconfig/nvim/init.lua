vim.env.PATH = vim.env.NVIM_PATH or vim.env.PATH

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.mouse = "a"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.g.mapleader = " "
vim.o.termguicolors = true
-- vim.lsp.set_log_level("debug")
vim.opt.guicursor = {
  "n-v-c:block",   -- normal/visual/command-line: block
  "i-ci-ve:hor20", -- insert, insert-command, visual-ex mode: underline (20%)
  "r-cr:hor20",    -- replace modes: underline (20%)
  "o:hor50",       -- operator-pending mode: underline (50%)
}

require("lazy").setup("plugins")
require("plugin-settings")
require("keymappings")
