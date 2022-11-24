local function map(mode, lhs, rhs, opts) local options = {noremap = true}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map('', '<leader>c', '"+y')       -- Copy to clipboard in normal, visual, select and operator modes
map('i', '<C-u>', '<C-g>u<C-u>')  -- Make <C-u> undo-friendly
map('i', '<C-w>', '<C-g>u<C-w>')  -- Make <C-w> undo-friendly

-- <Tab> to navigate the completion menu
map('i', '<S-Tab>', 'pumvisible() ? "\\<C-p>" : "\\<Tab>"', {expr = true})
map('i', '<Tab>', 'pumvisible() ? "\\<C-n>" : "\\<Tab>"', {expr = true})

map('n', '<C-l>', '<cmd>noh<CR>')    -- Clear highlights
map('n', '<leader>o', 'm`o<Esc>``')  -- Insert a newline in normal

-- quit / write with leader key shortcut.
map('n', '<leader>q', '<cmd>q<CR>')
map('n', '<leader>w', '<cmd>w<CR>')

-- BufOnly Mappings
map('n', '<leader>x', '<cmd>BufOnly<CR>', { noremap = true, silent = true })

-- Telescope Mappings
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
map("n","<leader>fd", "<cmd>Telescope file_browser<CR>", { noremap = true })
map("n", "<leader>fm", "<cmd>Telescope marks<CR>")
-- LSP mappings are in plugins/lsp-settings.lua

-- Customs
local utils = require('utils')
vim.keymap.set('n', '<leader>fn', utils.get_current_file_name)

-- relative path (src/foo.txt)
map('n', '<leader>cf', '<cmd>let @+=expand("%")<CR>', {})

-- absolute path (/something/src/foo.txt)
map('n', '<leader>cF', '<cmd>let @+=expand("%:p")<CR>', {})

-- filename (foo.txt)
map('n', '<leader>ct', '<cmd>let @+=expand("%:t")<CR>', {})

-- directory name (/something/src)
map('n', '<leader>ch', '<cmd>let @+=expand("%:p:h")<CR>', {})

