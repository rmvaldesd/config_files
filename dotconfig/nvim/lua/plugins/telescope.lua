return {
    'nvim-telescope/telescope.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim',
        "nvim-telescope/telescope-file-browser.nvim",
        'nvim-telescope/telescope-fzf-native.nvim',
        "nvim-telescope/telescope-live-grep-args.nvim",
        "nvim-telescope/telescope-dap.nvim",

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
        vim.keymap.set("n", "<leader>fc", "<cmd>Telescope flutter commands<CR>",
            { desc = '[Telescope] flutter - commands' })
        vim.keymap.set("n", "<leader>fd", "<cmd>Telescope file_browser<CR>",
            { noremap = true, desc = '[Telescope] files - browse files' })
        vim.keymap.set("n", "<leader>fe", builtin.lsp_definitions, { desc = '[LSP] definitions of symbol (picker)' })
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
        vim.keymap.set("n", "<leader>fm", "<cmd>Telescope marks<CR>",
            { desc = '[Telescope] looking for current set marks' })
        vim.keymap.set("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>",
            { desc = '[LSP] references — every usage of symbol' })
        vim.keymap.set("n", "<leader>fi", builtin.lsp_incoming_calls,
            { desc = '[LSP] incoming calls — callers of this function' })
        vim.keymap.set("n", "<leader>fo", builtin.lsp_outgoing_calls,
            { desc = '[LSP] outgoing calls — functions this one calls' })
        vim.keymap.set("n", "<leader>fs",
            function() builtin.lsp_document_symbols({ symbol_width = 45 }) end,
            { desc = '[LSP] document symbols — functions/types in THIS file' })
        vim.keymap.set("n", "<leader>fF",
            function() builtin.lsp_document_symbols({ symbol_width = 45, symbols = { "function", "method" } }) end,
            { desc = '[LSP] document functions — only functions/methods in THIS file' })
        vim.keymap.set("n", "<leader>fw", builtin.lsp_dynamic_workspace_symbols,
            { desc = '[LSP] workspace symbols — search any symbol project-wide' })

        vim.keymap.set("n", "<leader>fa", builtin.diagnostics, { desc = '[LSP] diagnostics — all problems (project)' })
        vim.keymap.set("n", "<leader>ft", builtin.lsp_type_definitions, { desc = '[LSP] type definition of symbol' })

        -- DAP pickers: browse debug commands / breakpoints / frames / variables.
        vim.keymap.set("n", "<leader>dc", "<cmd>Telescope dap commands<CR>", { desc = '[Telescope] dap commands' })
        vim.keymap.set("n", "<leader>dB", "<cmd>Telescope dap list_breakpoints<CR>",
            { desc = '[Telescope] dap list breakpoints' })
        vim.keymap.set("n", "<leader>dv", "<cmd>Telescope dap variables<CR>", { desc = '[Telescope] dap variables' })
        vim.keymap.set("n", "<leader>dF", "<cmd>Telescope dap frames<CR>", { desc = '[Telescope] dap frames' })

        -- To get fzf loaded and working with telescope, you need to call
        -- load_extension, somewhere after setup function:
        require('telescope').load_extension("fzf")
        require("telescope").load_extension("file_browser")
        require("telescope").load_extension("flutter")
        require("telescope").load_extension("live_grep_args")
        require("telescope").load_extension("dap")
    end
}
