return {
  {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-symbols.nvim',
    'wbthomason/packer.nvim',
    'ojroques/vim-oscyank',
    --'williamboman/nvim-lsp-installer'
    {
      'williamboman/mason.nvim',
      config = function()
        require("mason").setup({
          ui = {
            icons = {
              server_installed = "✓",
              server_pending = "➜",
              server_uninstalled = "✗"
            }
          }
        })
      end
    },
    {
      'williamboman/mason-lspconfig.nvim',
      config = function()
        require("mason-lspconfig").setup {
          ensure_installed = { 'pyright', 'gopls', 'eslint', 'tsserver', 'bashls', 'cssls', 'html', 'lua_ls', 'jsonls',
            'clangd', 'lemminx' },
        }
      end
    },

    'tpope/vim-commentary',
    'tpope/vim-fugitive',
    'tpope/vim-surround',

    'ellisonleao/gruvbox.nvim',
    'vim-airline/vim-airline',
    'vim-airline/vim-airline-themes',

    'rafcamlet/nvim-luapad',
    'L3MON4D3/LuaSnip',
    'saadparwaiz1/cmp_luasnip',
    {
      'hrsh7th/nvim-cmp',
      dependencies = {},
      config = function()
        local cmp = require 'cmp'
        local luasnip = require('luasnip')
        cmp.setup {
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          window = {
            -- completion = cmp.config.window.bordered(),
            -- documentation = cmp.config.window.bordered(),
          },
          mapping = cmp.mapping.preset.insert({
            ['<C-d>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm {
              behavior = cmp.ConfirmBehavior.Replace,
              select = true,
            },
            ['<Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              else
                fallback()
              end
            end, { 'i', 's' }),
            ['<S-Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end, { 'i', 's' }),
          }),
          sources = {
            { name = 'nvim_lsp' },
            { name = 'luasnip' },
            { name = 'buffer' },
            { name = 'nvim_lsp_signature_help' }
          },
        }
      end
    },
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    { 'numtostr/BufOnly.nvim',                    cmd = 'BufOnly' },


    -- Telescope
    "nvim-telescope/telescope-file-browser.nvim",
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    'kyazdani42/nvim-web-devicons',

    -- Notes - Wiki
    'lervag/wiki.vim',

    -- browse things.
    'preservim/tagbar',
    --'preservim/nerdtree',

    -- Debugging
    'mfussenegger/nvim-dap-python',


  }
}
