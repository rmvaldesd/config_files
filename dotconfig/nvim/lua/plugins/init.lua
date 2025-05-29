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
			config = function()
				require("mason-lspconfig").setup({
					ensure_installed = {
						"pyright",
						"gopls",
						"eslint",
						"bashls",
						"html",
						"lua_ls",
						"jsonls",
						"clangd",
						"lemminx",
					},
				})
			end,
		},

		--'tpope/vim-commentary',
		"tpope/vim-fugitive",

		"ellisonleao/gruvbox.nvim",
		"vim-airline/vim-airline",
		"vim-airline/vim-airline-themes",

		"rafcamlet/nvim-luapad",
		"L3MON4D3/LuaSnip",
		{ "numtostr/BufOnly.nvim", cmd = "BufOnly" },

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
}
