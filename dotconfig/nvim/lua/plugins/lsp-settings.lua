-- ----------------------nvim-lsp-installer setup-----------------------
local util = require 'lspconfig.util'
require("mason").setup({
  -- List of servers to automatically install
  -- automatically detect which servers to install (based on which servers are set up via lspconfig)
  ui = {
    icons = {
      server_installed = "✓",
      server_pending = "➜",
      server_uninstalled = "✗"
    }
  }
})

require("mason-lspconfig").setup {
  ensure_installed = { 'pyright', 'gopls', 'eslint', 'tsserver', 'bashls', 'cssls', 'html', 'lua_ls', 'jsonls',
    'clangd', 'lemminx' },
}


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



-- nvim-cmp setup
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
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities,
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_dir = function(fname)
    return util.root_pattern 'go.work' (fname) or util.root_pattern('go.mod', '.git')(fname)
  end,
  single_file_support = true,
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
