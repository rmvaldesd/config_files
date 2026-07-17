-- ----------------------nvim-lsp-installer setup-----------------------
return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "saghen/blink.cmp",
  },
  config = function()
    local util = require("lspconfig.util")
    local async = require("lspconfig.async")
    -- ------------------------- LSP Setup ---------------------------------
    -- Mappings.
    -- See `:help vim.diagnostic.*` for documentation on any of the below functions
    local opts = function(desc)
      return { noremap = true, silent = true, desc = desc }
    end
    vim.keymap.set("n", "<space>do", vim.diagnostic.open_float, opts("[Lsp] - diagnostics open float"))
    vim.keymap.set("n", "<space>dh", vim.diagnostic.goto_prev, opts("[Lsp] - diagnostics go prev"))
    vim.keymap.set("n", "<space>dn", vim.diagnostic.goto_next, opts("[Lsp] - diagnostics go next"))
    vim.keymap.set("n", "<space>dsl", vim.diagnostic.setloclist, opts("[Lsp] - diagnostics open float"))

    local on_attach = function(client, bufnr)
      vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      local bufopts = function(bufnbr, desc)
        return { noremap = true, silent = true, buffer = bufnr, desc = desc }
      end
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts(bufnr, "[Lsp] - [g]o to [D]eclaration"))
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts(bufnr, "[Lsp] - [g]o to [d]efinition"))
      vim.keymap.set("n", "gh", vim.lsp.buf.hover, bufopts(bufnr, "[Lsp] - [go] to [h]over information"))
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts(bufnr, "[Lsp] - [g]o to [i]mplementation"))
      vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, bufopts(bufnr, "[Lsp] - [g]o [s]ignature help"))
      vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts(bufnr, "[Lsp] - [g]o to [r]eferences"))
      vim.keymap.set("n", "<space>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
      end, bufopts(bufnr, "[Lsp] - [t]oggle inlay [h]ints"))
      vim.keymap.set(
        "n",
        "<space>wa",
        vim.lsp.buf.add_workspace_folder,
        bufopts(bufnr, "[Lsp] - [w]orkspace [a]dd folder")
      )
      vim.keymap.set(
        "n",
        "<space>wr",
        vim.lsp.buf.remove_workspace_folder,
        bufopts(bufnr, "[Lsp] - [w]orkspace [r]emove folder")
      )
      vim.keymap.set("n", "<space>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, bufopts(bufnr, "[Lsp] - [w]orkspace [l]ist folders"))
      vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, bufopts(bufnr, "[Lsp] - Type Definition"))
      vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts(bufnr, "[Lsp] - [r]e[n]ame symbol"))
      vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts(bufnr, "[Lsp] - [c]ode [a]ction"))
      -- vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
      vim.keymap.set("n", "<space>f", function()
        vim.lsp.buf.format({ async = true })
      end, bufopts(bufnr, "[Lsp] - [f]ormat document"))

      -- Turn inlay hints on by default when the server provides them.
      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end
    end

    local lsp_flags = {
      -- This is the default in Nvim 0.7+
      debounce_text_changes = 300,
    }

    -- local capabilities = {
    --   textDocument = {
    --     foldingRange = {
    --       dynamicRegistration = false,
    --       lineFoldingOnly = true,
    --     },
    --   },
    -- }
    -- capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    -- LSPs with default setup: bashls (Bash), cssls (CSS), html (HTML), clangd (C/C++), jsonls (JSON)
    for _, lsp in ipairs({ "bashls", "cssls", "html", "clangd", "jsonls", "ts_ls" }) do
      vim.lsp.config(lsp, {
        on_attach = on_attach,
        flags = lsp_flags,
        capabilities = capabilities,
      })
    end

    vim.lsp.config("gopls", {
      cmd = { "gopls", "-remote=auto" },
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      settings = {
        gopls = {
          -- Static analysis
          staticcheck = true,
          gofumpt = true,
          analyses = {
            unusedparams = true,
            unusedwrite = true,
            shadow = true,
            nilness = true,
            useany = true,
            fieldalignment = false,
          },
          -- Completion quality
          usePlaceholders = true,
          completeUnimported = true,
          -- Inlay hints
          hints = {
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            constantValues = true,
            functionTypeParameters = true,
            parameterNames = true,
            rangeVariableTypes = true,
          },
          -- Code lenses (run test / tidy / generate above the code)
          codelenses = {
            gc_details = true,
            generate = true,
            regenerate_cgo = true,
            test = true,
            tidy = true,
            upgrade_dependency = true,
            vendor = true,
          },
          semanticTokens = true,
          -- Skip noisy/heavy dirs for faster indexing
          directoryFilters = { "-.git", "-node_modules", "-bazel-out", "-bazel-bin" },
        },
      },
    })

    local useLsp = os.getenv("NVIMULSP")
    if useLsp == "true" then
      require("lspconfig.configs").ulsp = {
        default_config = {
          cmd = { "socat", "-", "tcp:localhost:27883,ignoreeof" },
          flags = { debounce_text_changes = 1000, },
          capabilities = vim.lsp.protocol.make_client_capabilities(),
          filetypes = { "go", "java" },
          root_dir = function(fname)
            local result = async.run_command({ "git", "rev-parse", "--show-toplevel" })
            if result and result[1] then return vim.trim(result[1]) end
            return util.root_pattern(".git")(fname)
          end,
          single_file_support = false,
          docs = {
            description =
            [[ uLSP brought to you by the IDE team! By utilizing uLSP in Neovim, you acknowledge that this integration is provided 'as-is' with no warranty, express or implied. We make no guarantees regarding its functionality, performance, or suitability for any purpose, and absolutely no support will be provided. Use at your own risk, and may the code gods have mercy on your soul ]],
          },
        },
      }
      require("lspconfig.configs").ulsp.setup({})
    end --LSPs with no default setup

    local python_root_files = {
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      "Pipfile",
      "pyrightconfig.json",
    }
    vim.lsp.config("pyright", {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { "python" },
      root_markers = python_root_files,
      single_file_support = true,
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = "workspace",
          },
        },
      },
    })

    vim.lsp.config("dartls", {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      filetypes = { "dart" },
      root_markers = { "pubspec.yaml" },
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
    })

    vim.lsp.config("rust_analyzer", {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      -- Server-specific settings...
      settings = {
        ["rust-analyzer"] = {},
      },
      cmd = {
        "rustup", "run", "stable", "rust-analyzer",
      }
    })

    vim.lsp.config("lua_ls", {
      on_attach = on_attach,
      flags = lsp_flags,
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = { globals = { "vim" } },
        },
      },
    })

    -- vim.lsp.config() only STORES config; vim.lsp.enable() actually starts the
    -- server (registers the FileType autocmd). Without this, on_attach never
    -- runs and none of the LSP keymaps (gd, gD, gh, gi, ...) get set.
    vim.lsp.enable({
      "bashls",
      "cssls",
      "html",
      "clangd",
      "jsonls",
      "ts_ls",
      "gopls",
      "pyright",
      "dartls",
      "rust_analyzer",
      "lua_ls",
    })
  end,
}
