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
    -- ------------------------- LSP Setup ---------------------------------
    -- Mappings.
    -- See `:help vim.diagnostic.*` for documentation on any of the below functions
    local opts = { noremap = true, silent = true }
    vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
    vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

    -- Use an on_attach function to only map the following keys
    -- after the language server attaches to the current buffer
    local on_attach = function(client, bufnr)
      -- Lsp-format setup --> https://github.com/lukas-reineke/lsp-format.nvim
      require("lsp-format").on_attach(client)
      -- Enable completion triggered by <c-x><c-o>
      vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      local bufopts = { noremap = true, silent = true, buffer = bufnr }
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
      vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, bufopts)
      vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
      vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
      vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
      -- vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
      vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
    end

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
