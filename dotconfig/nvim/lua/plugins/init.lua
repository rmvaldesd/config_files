return {
  {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-symbols.nvim",
    "ojroques/vim-oscyank",
    --'williamboman/nvim-lsp-installer'
    {
      "williamboman/mason.nvim",
      config = function()
        require("mason").setup({
          ui = {
            icons = {
              server_installed = "✓",
              server_pending = "➜",
              server_uninstalled = "✗",
            },
          },
        })
      end,
    },
    {
      "williamboman/mason-lspconfig.nvim",
      dependencies = { "williamboman/mason.nvim" },
      config = function()
        require("mason-lspconfig").setup({
          ensure_installed = {
            "pyright",
            "eslint",
            "bashls",
            "html",
            "lua_ls",
            "jsonls",
            "clangd",
            "lemminx",
            "ts_ls",
          },
          automatic_installation = false,
          handlers = {
            -- Disable gopls handler to prevent auto-installation
            gopls = function() end,
          },
        })
      end,
    },

    --'tpope/vim-commentary',
    "tpope/vim-fugitive",

    -- "ellisonleao/gruvbox.nvim",
    -- {
    --   "folke/tokyonight.nvim",
    --   lazy = false,
    --   priority = 1000,
    --   opts = {},
    -- },
    "rebelot/kanagawa.nvim",


    "rafcamlet/nvim-luapad",
    { "numtostr/BufOnly.nvim",                    cmd = "BufOnly" },

    -- Telescope
    "nvim-telescope/telescope-file-browser.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "kyazdani42/nvim-web-devicons",
    -- Debugging
    "mfussenegger/nvim-dap-python",
    {
      "kylechui/nvim-surround",
      version = "*", -- Use for stability; omit to use `main` branch for the latest features
      event = "VeryLazy",
      config = function()
        require("nvim-surround").setup({
          -- Configuration here, or leave empty to use defaults
        })
      end,
    },
  },
  -- mini icons used for oil.nvim
  { "echasnovski/mini.nvim", version = false },
  {
    "vhyrro/luarocks.nvim",
    priority = 1000, -- Very high priority is required, luarocks.nvim should run as the first plugin in your config.
    config = true,
  },
  {
    "ojroques/nvim-bufdel",
    config = function()
      require("bufdel").setup({
        next = "tabs",
        quit = true, -- quit Neovim when last buffer is closed
      })
    end,
  },
  {
    "debugloop/telescope-undo.nvim",
    dependencies = { -- note how they're inverted to above example
      {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
      },
    },
    keys = {
      { -- lazy style key map
        "<leader>u",
        "<cmd>Telescope undo<cr>",
        desc = "undo history",
      },
    },
    opts = {
      -- don't use `defaults = { }` here, do this in the main telescope spec
      extensions = {
        undo = {
          -- telescope-undo.nvim config, see below
        },
        -- no other extensions here, they can have their own spec too
      },
    },
    config = function(_, opts)
      -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
      -- configs for us. We won't use data, as everything is in it's own namespace (telescope
      -- defaults, as well as each extension).
      require("telescope").setup(opts)
      require("telescope").load_extension("undo")
    end,
  },
}
