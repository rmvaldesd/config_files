-- ----------------------nvim-lsp-installer setup-----------------------
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    local util = require 'lspconfig.util'
    -- ------------------------- LSP Setup ---------------------------------
    -- Mappings.
    -- See `:help vim.diagnostic.*` for documentation on any of the below functions
    local opts = function(desc)
      return { noremap = true, silent = true, desc = desc }
    end
    vim.keymap.set('n', '<space>do', vim.diagnostic.open_float, opts('[Lsp] - diagnostics open float'))
    vim.keymap.set('n', '<space>dh', vim.diagnostic.goto_prev, opts('[Lsp] - diagnostics go prev'))
    vim.keymap.set('n', '<space>dn', vim.diagnostic.goto_next, opts('[Lsp] - diagnostics go next'))
    vim.keymap.set('n', '<space>dsl', vim.diagnostic.setloclist, opts('[Lsp] - diagnostics open float'))

    local on_attach = function(client, bufnr)
      -- Lsp-format setup --> https://github.com/lukas-reineke/lsp-format.nvim
      -- require("lua.plugins.format").on_attach(client)
      -- Enable completion triggered by <c-x><c-o>
      vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      local bufopts = function(bufnbr, desc)
        return { noremap = true, silent = true, buffer = bufnr, desc = desc }
      end
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts(bufnr, '[Lsp] - [g]o to [D]eclaration'))
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts(bufnr, '[Lsp] - [g]o to [d]efinition'))
      vim.keymap.set('n', 'gh', vim.lsp.buf.hover, bufopts(bufnr, '[Lsp] - [go] to [h]over information'))
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts(bufnr, '[Lsp] - [g]o to [i]mplementation'))
      vim.keymap.set('n', 'gh', vim.lsp.buf.signature_help, bufopts(bufnr, '[Lsp] - [go] signature [h]elp'))
      vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder,
        bufopts(bufnr, '[Lsp] - [w]orkspace [a]dd folder'))
      vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder,
        bufopts(bufnr, '[Lsp] - [w]orkspace [r]emove folder'))
      vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, bufopts(bufnr, '[Lsp] - [w]orkspace [l]ist folders'))
      vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts(bufnr, '[Lsp] - Type Definition'))
      vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts(bufnr, '[Lsp] - [r]e[n]ame symbol'))
      vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts(bufnr, '[Lsp] - [c]ode [a]ction'))
      -- vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
      vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end,
        bufopts(bufnr, '[Lsp] - [f]ormat document'))
    end

    local lsp_flags = {
      -- This is the default in Nvim 0.7+
      debounce_text_changes = 300,
    }

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
      init_options = {
        staticcheck = true,
        -- gofumpt = true,
        -- memoryMode = "DegradeClosed",
      },
      filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
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
