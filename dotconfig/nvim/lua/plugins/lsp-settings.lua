-- ----------------------nvim-lsp-installer setup-----------------------
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    local util = require 'lspconfig.util'

    -- Use an on_attach function to only map the following keys
    -- after the language server attaches to the current buffer
    local on_attach = function(client, bufnr)
      -- Lsp-format setup --> https://github.com/lukas-reineke/lsp-format.nvim
      require("lsp-format").on_attach(client)
      -- Enable completion triggered by <c-x><c-o>
      vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
    end



    -- nvim-cmp setup

    -- -----------------------end nvim-cmp configuration ---------------------

    local lsp_flags = {
      -- This is the default in Nvim 0.7+
      debounce_text_changes = 300,
    }


    -- nvim-cmp supports additional completion capabilities
    --local capabilities = vim.lsp.protocol.make_client_capabilities()
    --capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
    local capabilities = require('cmp_nvim_lsp').default_capabilities()


    -- LSPs with default setup: bashls (Bash), cssls (CSS), html (HTML), clangd (C/C++), jsonls (JSON)
    for _, lsp in ipairs { 'tsserver', 'bashls', 'cssls', 'html', 'clangd', 'jsonls', 'lua_ls' } do
      require('lspconfig')[lsp].setup {
        on_attach = on_attach,
        flags = lsp_flags,
        capabilities = capabilities,
      }
    end

    -- LSPs with no default setup
    require('lspconfig')['gopls'].setup {
      cmd = { 'gopls', '-remote=auto' },
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
      --root_dir = function(fname)
      --  return util.root_pattern 'go.work' (fname) or util.root_pattern('go.mod', '.git')(fname)
      -- end,
      -- single_file_support = true,
    }


    local python_root_files = {
      'pyproject.toml',
      'setup.py',
      'setup.cfg',
      'requirements.txt',
      'Pipfile',
      'pyrightconfig.json',
    }
    require('lspconfig')['pyright'].setup {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { 'python' },
      root_dir = util.root_pattern(unpack(python_root_files)),
      single_file_support = true,
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = 'workspace',
          },
        },
      },
    }


    require('lspconfig')['dartls'].setup {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { 'dart' },
      root_dir = util.root_pattern 'pubspec.yaml',
      single_file_support = true,
      init_options = {
        onlyAnalyzeProjectsWithOpenFiles = true,
        suggestFromUnimportedLibraries = true,
        closingLabels = true,
        outline = true,
        flutterOutline = true,
      },
      settings = {
        dart = {
          completeFunctionCalls = true,
          showTodos = true,
        },
      },
    }


    require('lspconfig')['rust_analyzer'].setup {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      -- Server-specific settings...
      settings = {
        ["rust-analyzer"] = {}
      }
    }

    require('lspconfig')['lua_ls'].setup {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = { globals = { 'vim' } }
        }
      }
    }
  end
}
