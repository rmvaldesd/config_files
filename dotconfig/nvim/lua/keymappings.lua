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

-- LSP mappings are in plugins/lsp-settings.lua

-- Customs
local utils = require('utils')
vim.keymap.set('n', '<leader>fn', utils.get_current_file_name, { desc = 'show current file name' })

-- relative path (src/foo.txt)
vim.keymap.set('n', '<leader>cp', '<cmd>let @+=expand("%")<CR>', { desc = 'copy relative file path (src/foo.txt)' })

-- absolute path (/something/src/foo.txt)
vim.keymap.set('n', '<leader>cP', '<cmd>let @+=expand("%:p")<CR>',
  { desc = 'copy absolute file path (/something/src/foo.txt)' })

-- filename (foo.txt)
vim.keymap.set('n', '<leader>cf', '<cmd>let @+=expand("%:t")<CR>', { desc = 'copy file name - (foo.txt)' })

-- directory name (/something/src)
vim.keymap.set('n', '<leader>cd', '<cmd>let @+=expand("%:p:h")<CR>', { desc = 'copy directory name - (/something/src)' })

--- moving throught the panes.
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'move to the right pane' })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'move to the left pane' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'move to the below pane' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'move to the above pane' })

--- resizing panes horizontally and vertically.
vim.keymap.set('n', '<S-Up>', ':resize -2<CR>', {})
vim.keymap.set('n', '<S-Down>', ':resize +2<CR>', {})
vim.keymap.set('n', '<S-Left>', ':vertical resize -2<CR>', {})
vim.keymap.set('n', '<S-Right>', ':vertical resize +2<CR>', {})

--- moving throught the buffers
vim.keymap.set('n', '<leader>h', '<cmd>bprevious<CR>', { desc = 'move previous buffer' })
vim.keymap.set('n', '<leader>l', '<cmd>bnext<CR>', { desc = 'move next buffer' })

--- Persevim (Nerdtree / TagBar)
vim.keymap.set('n', '<leader>m', '<cmd>NERDTreeToggle<CR>', { desc = 'Nerdtree - toggle files menu' })
vim.keymap.set('n', '<leader>n', '<cmd>TagbarToggle<CR>', { desc = 'TagBar - toggle tagbar menu' })


-- show current line diagnostics
vim.keymap.set("n", "<leader>sd", vim.diagnostic.open_float, { desc = 'show current line diagnostics' })

-- Open netrw in 25% split in tree view
vim.keymap.set("n", "<leader>e", ":25Lex<CR>") -- space+e toggles netrw tree view

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = 'Yank block Between ([{}]) ' })
