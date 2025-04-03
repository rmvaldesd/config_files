return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    "nvim-telescope/telescope-file-browser.nvim",
    'nvim-telescope/telescope-fzf-native.nvim',
    "nvim-telescope/telescope-live-grep-args.nvim",

  },

  config = function()
    -- You dont need to set any of these options. These are the default ones. Only
    -- the loading is important
    require('telescope').setup {
      defaults = {
        path_display = { "truncate" },
      },
      extensions = {
        fzf = {
          fuzzy = true,                   -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true,    -- override the file sorter
          case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
          -- the default case_mode is "smart_case"
        }
      },
    }

    local get_selection = function()
      return vim.fn.getregion(
        vim.fn.getpos ".", vim.fn.getpos "v", { mode = vim.fn.mode() }
      )
    end

    -- Telescope Mappings
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = '[Telescope] buffers - show open buffers' })
    vim.keymap.set("n", "<leader>fc", "<cmd>Telescope flutter commands<CR>", { desc = '[Telescope] flutter - commands' })
    vim.keymap.set("n", "<leader>fd", "<cmd>Telescope file_browser<CR>",
      { noremap = true, desc = '[Telescope] files - browse files' })
    vim.keymap.set("n", "<leader>fe", builtin.lsp_definitions, { desc = '[Telescope] lsp word definition' })
    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = '[Telescope] files - find files' })
    vim.keymap.set('n', '<leader>fG', builtin.live_grep, { desc = '[Telescope] files - find text live grep' })
    vim.keymap.set('v', '<leader>vg',
      function()
        require("telescope.builtin").live_grep {
          default_text = table.concat(get_selection())
        }
      end,
      { desc = '[Telescope] files - find text live grep using visual mode selection' }
    )
    vim.keymap.set("n", "<leader>fg", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>",
      { desc = '[Telescope] Live Grep args' })
    vim.keymap.set('n', '<leader>ht', builtin.help_tags, { desc = '[Telescope] help tags' })
    vim.keymap.set('n', '<leader>km', builtin.keymaps, { desc = '[Telescope] keymaps' })
    vim.keymap.set("n", "<leader>fm", "<cmd>Telescope marks<CR>", { desc = '[Telescope] looking for current set marks' })
    vim.keymap.set("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { desc = '[Telescope] lsp references' })
    vim.keymap.set("n", "<leader>fi", builtin.lsp_incoming_calls, { desc = '[Telescope] lsp incoming calls' })
    vim.keymap.set("n", "<leader>fo", builtin.lsp_outgoing_calls, { desc = '[Telescope] lsp outgoing calls' })
    -- vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = 'lsp document symbols' })
    vim.keymap.set("n", "<leader>fs", function() builtin.lsp_document_symbols({ symbol_width = 80 }) end,
      { desc = '[Telescope] lsp document symbols' })

    vim.keymap.set("n", "<leader>fa", builtin.diagnostics, { desc = '[Telescope] document diagnostics' })
    vim.keymap.set("n", "<leader>ft", builtin.lsp_type_definitions, { desc = '[Telescope] lsp type definition' })

    -- To get fzf loaded and working with telescope, you need to call
    -- load_extension, somewhere after setup function:
    require('telescope').load_extension("fzf")
    require("telescope").load_extension("file_browser")
    require("telescope").load_extension("flutter")
    require("telescope").load_extension("live_grep_args")
  end
}
