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

return require('lazy').setup({
  'nvim-lua/plenary.nvim',
  'nvim-telescope/telescope-symbols.nvim',
  'wbthomason/packer.nvim',
  'ojroques/vim-oscyank',
  --'williamboman/nvim-lsp-installer'
  'williamboman/mason.nvim',
  'williamboman/mason-lspconfig.nvim',

  'neovim/nvim-lspconfig',
  'tpope/vim-commentary',
  'tpope/vim-fugitive',
  'tpope/vim-surround',

  'ellisonleao/gruvbox.nvim',
  'vim-airline/vim-airline',
  'vim-airline/vim-airline-themes',
  'norcalli/nvim-colorizer.lua',

  'rafcamlet/nvim-luapad',
  'L3MON4D3/LuaSnip',
  'saadparwaiz1/cmp_luasnip',
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-nvim-lsp',
  'hrsh7th/cmp-buffer',
  { 'numtostr/BufOnly.nvim',         cmd = 'BufOnly' },
  {
    'akinsho/flutter-tools.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      require("plugins/flutter-tools").setup()
    end
  },

  -- notifications
  'rcarriga/nvim-notify',

  -- Telescope
  { 'nvim-telescope/telescope.nvim', dependencies = 'nvim-lua/plenary.nvim' },
  "nvim-telescope/telescope-file-browser.nvim",
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  'kyazdani42/nvim-web-devicons',

  -- Notes - Wiki
  'lervag/wiki.vim',

  -- browse things.
  'preservim/tagbar',
  'preservim/nerdtree',

  -- Debugging
  'mfussenegger/nvim-dap',
  'mfussenegger/nvim-dap-python',
  'leoluz/nvim-dap-go',
  'rcarriga/nvim-dap-ui',

  -- Formatting
  'lukas-reineke/lsp-format.nvim',

  -- Treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
  },

  {
    "ThePrimeagen/harpoon",
    dependencies = 'nvim-lua/plenary.nvim'
  },

})
