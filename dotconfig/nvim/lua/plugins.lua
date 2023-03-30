local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
  use { 'nvim-lua/plenary.nvim' }
  use { 'nvim-telescope/telescope-symbols.nvim' }
  use 'wbthomason/packer.nvim'
  use 'ojroques/vim-oscyank'
  --use 'williamboman/nvim-lsp-installer'
  use { 'williamboman/mason.nvim' }
  use { 'williamboman/mason-lspconfig.nvim' }

  use 'neovim/nvim-lspconfig'
  use 'tpope/vim-commentary'
  use 'tpope/vim-fugitive'
  use 'tpope/vim-surround'

  use { 'ellisonleao/gruvbox.nvim' }
  use 'vim-airline/vim-airline'
  use 'vim-airline/vim-airline-themes'
  use { 'norcalli/nvim-colorizer.lua' }

  use 'rafcamlet/nvim-luapad'
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-buffer'
  use { 'numtostr/BufOnly.nvim', cmd = 'BufOnly' }
  use {
    'akinsho/flutter-tools.nvim',
    requires = 'nvim-lua/plenary.nvim',
    config = function()
      require("plugins/flutter-tools").setup()
    end
  }

  -- notifications
  use { 'rcarriga/nvim-notify' }

  -- Telescope
  use { 'nvim-telescope/telescope.nvim', requires = 'nvim-lua/plenary.nvim' }
  use { "nvim-telescope/telescope-file-browser.nvim" }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  use 'kyazdani42/nvim-web-devicons'

  -- Notes - Wiki
  use { 'lervag/wiki.vim' }

  -- browse things.
  use { 'preservim/tagbar' }
  use { 'preservim/nerdtree' }

  -- Debugging
  use { "mfussenegger/nvim-dap" }
  use { "mfussenegger/nvim-dap-python" }
  use { "leoluz/nvim-dap-go" }
  use { "rcarriga/nvim-dap-ui" }

  -- Formatting
  use "lukas-reineke/lsp-format.nvim"

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
