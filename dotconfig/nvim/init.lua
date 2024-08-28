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
vim.g.mapleader = " "
vim.o.termguicolors = true
vim.g.netrw_banner = 0       -- gets rid of the annoying banner for netrw
vim.g.netrw_browse_split = 4 -- open in prior window
vim.g.netrw_altv = 1         -- change from left splitting to right splitting
vim.g.netrw_liststyle = 3    -- tree style view in netrw

require('lazy').setup('plugins')
require("plugin-settings")
require("keymappings")

local function goFormat(wait_ms)
  -- Prefer `format` if available because `formatting_sync` has been deprecated as of nvim v0.8.0.
  if vim.lsp.buf.format == nil then
    vim.lsp.buf.formatting_sync(nil, wait_ms)
  else
    vim.lsp.buf.format({
      timeout_ms = wait_ms,
    })
  end
  -- Too slow code... try to fix
  --[[ local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
      else
        vim.lsp.buf.execute_command(r.command)
      end
    end
  end ]]
end

--[[ vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function(args)
    goFormat(6000)
  end,
}) ]]
