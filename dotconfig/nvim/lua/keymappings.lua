-- vim.keymap.set('', '<leader>c', '"+y', { desc = 'copy to clipboard in normal, visual, select and operator modes' }) -- Copy to clipboard in normal, visual, select and operator modes
vim.keymap.set('i', '<C-u>', '<C-g>u<C-u>') -- Make <C-u> undo-friendly
-- vim.keymap.set('i', '<C-w>', '<C-g>u<C-w>') -- Make <C-w> undo-friendly

-- <Tab> to navigate the completion menu
vim.keymap.set('i', '<S-Tab>', 'pumvisible() ? "\\<C-p>" : "\\<Tab>"', { expr = true })
vim.keymap.set('i', '<Tab>', 'pumvisible() ? "\\<C-n>" : "\\<Tab>"', { expr = true })

-- vim.keymap.set('n', '<C-l>', '<cmd>noh<CR>')    -- Clear highlights
vim.keymap.set('n', '<leader>o', 'm`o<Esc>``', { desc = 'insert newline in normal' }) -- Insert a newline in normal

-- quit / write with leader key shortcut.
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = "quick quit" })
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = "quick save file" })

-- BufOnly Mappings
vim.keymap.set('n', '<leader>x', '<cmd>BufOnly<CR>',
  { noremap = true, silent = true, desc = 'buffers - close all but the current one' })

-- Telescope Mappings
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'files - find files' })
vim.keymap.set('n', '<leader>fG', builtin.live_grep, { desc = 'files - find text live grep' })
vim.keymap.set("n", "<leader>fg", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'buffers - show open buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'help tags' })
vim.keymap.set('n', '<leader>fp', builtin.keymaps, { desc = 'keymaps' })
vim.keymap.set("n", "<leader>fd", "<cmd>Telescope file_browser<CR>", { noremap = true, desc = 'files - browse files' })
vim.keymap.set("n", "<leader>fm", "<cmd>Telescope marks<CR>", { desc = 'looking for current set marks' })
vim.keymap.set("n", "<leader>fc", "<cmd>Telescope flutter commands<CR>", { desc = 'flutter - commands' })
vim.keymap.set("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { desc = 'lsp references' })
vim.keymap.set("n", "<leader>fi", builtin.lsp_incoming_calls, { desc = 'lsp incoming calls' })
vim.keymap.set("n", "<leader>fo", builtin.lsp_outgoing_calls, { desc = 'lsp outgoing calls' })
-- vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = 'lsp document symbols' })
vim.keymap.set("n", "<leader>fs", function() builtin.lsp_document_symbols({ symbol_width = 80 }) end,
  { desc = 'lsp document symbols' })

vim.keymap.set("n", "<leader>fa", builtin.diagnostics, { desc = 'document diagnostics' })
vim.keymap.set("n", "<leader>fe", builtin.lsp_definitions, { desc = 'lsp word definition' })
vim.keymap.set("n", "<leader>ft", builtin.lsp_type_definitions, { desc = 'lsp type definition' })

-- LSP mappings are in plugins/lsp-settings.lua

-- Customs
local utils = require('utils')
vim.keymap.set('n', '<leader>fn', utils.get_current_file_name, { desc = 'show current file name' })

-- relative path (src/foo.txt)
vim.keymap.set('n', '<leader>cp', '<cmd>let @+=expand("%")<CR>', { desc = 'copy file path - relative (src/foo.txt)' })

-- absolute path (/something/src/foo.txt)
vim.keymap.set('n', '<leader>cP', '<cmd>let @+=expand("%:p")<CR>',
  { desc = 'copy file path = absolute (/something/src/foo.txt)' })

-- filename (foo.txt)
vim.keymap.set('n', '<leader>cf', '<cmd>let @+=expand("%:t")<CR>', { desc = 'copy file name - (foo.txt)' })

-- directory name (/something/src)
vim.keymap.set('n', '<leader>cd', '<cmd>let @+=expand("%:p:h")<CR>', { desc = 'copy directory name - (/something/src)' })

--- moving throught the panes.
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Ctrl + l move to the right pane' })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Ctrl + h move to the left pane' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Ctrl + k move to the below pane' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Ctrl + j move to the above pane' })

--- resizing panes horizontally and vertically.
vim.keymap.set('n', '<S-Up>', ':resize -2<CR>', {})
vim.keymap.set('n', '<S-Down>', ':resize +2<CR>', {})
vim.keymap.set('n', '<S-Left>', ':vertical resize -2<CR>', {})
vim.keymap.set('n', '<S-Right>', ':vertical resize +2<CR>', {})

--- moving throught the buffers
vim.keymap.set('n', '<leader>h', '<cmd>bprevious<CR>', { desc = 'buffers - move previous' })
vim.keymap.set('n', '<leader>l', '<cmd>bnext<CR>', { desc = 'buffers - move next' })

--- Persevim (Nerdtree / TagBar)
vim.keymap.set('n', '<leader>m', '<cmd>NERDTreeToggle<CR>', { desc = 'Nerdtree - toggle files menu' })
vim.keymap.set('n', '<leader>n', '<cmd>TagbarToggle<CR>', { desc = 'TagBar - toggle tagbar menu' })


--- dap mappings
local dap_ok, dap = pcall(require, "dap")
local dap_ui_ok, ui = pcall(require, "dapui")

if not (dap_ok and dap_ui_ok) then
  require("notify")("nvim-dap or dap-ui not installed!", "warning") -- nvim-notify is a separate plugin, I recommend it too!
  return
end

vim.fn.sign_define('DapBreakpoint', { text = 'X' })

-- Start debugging session
vim.keymap.set("n", "<leader>ds", function()
  dap.continue()
  ui.toggle({})
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false) -- Spaces buffers evenly
end, { desc = 'dap - start debugging session' })

-- Set breakpoints, get variable values, step into/out of functions, etc.
vim.keymap.set("n", "<leader>dl", require("dap.ui.widgets").hover, { desc = 'dap - hover information' })
vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = 'dap - toggle breakpoints' })
vim.keymap.set("n", "<leader>B",
  function()
    dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
  end,
  { desc = 'dap - condition breakpoint' }
)
vim.keymap.set("n", "<F5>", dap.continue, { desc = 'dap - continue / start debugging' })
vim.keymap.set("n", "<F1>", dap.step_into, { desc = 'dap - debugging step into' })
vim.keymap.set("n", "<F2>", dap.step_over, { desc = 'dap - debugging step over' })
vim.keymap.set("n", "<F3>", dap.step_out, { desc = 'dap - debugging step out' })
vim.keymap.set("n", "<F7>", ui.toggle, { desc = 'dap - see last session result.' })
vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = 'dap - terminate debugging' })
-- vim.keymap.set("n", "<leader>dg", require("dap-go").debug_test, { desc = 'dap - debug go current test' })
vim.keymap.set("n", "<leader>dC", function()
  dap.clear_breakpoints()
  require("notify")("Breakpoints cleared", "warn")
end, { desc = 'dap - Clear breakpoints' })

-- Close debugger and clear breakpoints
vim.keymap.set("n", "<leader>de", function()
  dap.clear_breakpoints()
  ui.toggle({})
  dap.terminate()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false)
  require("notify")("Debugger session ended", "warn")
end, { desc = 'dap - close debugger and clear endpoints' })

-- Harpoon keymappings
vim.keymap.set("n", "<leader>sa", require("harpoon.mark").add_file, { desc = 'harpoon - add file' })
vim.keymap.set("n", "<leader>ss", require("harpoon.ui").toggle_quick_menu, { desc = 'harpoon - toggle quick menu' })

-- show current line diagnostics
vim.keymap.set("n", "<leader>sd", vim.diagnostic.open_float, { desc = 'show current line diagnostics' })

-- Open netrw in 25% split in tree view
vim.keymap.set("n", "<leader>e", ":25Lex<CR>") -- space+e toggles netrw tree view

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = 'Yank block Between ([{}]) ' })
