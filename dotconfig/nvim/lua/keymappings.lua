-- quit / write with leader key shortcut.
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "quick quit" })
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "quick save file" })

-- relative path (src/foo.txt)
vim.keymap.set("n", "<leader>cp", '<cmd>let @+=expand("%")<CR>', { desc = "copy relative file path (src/foo.txt)" })
-- absolute path (/something/src/foo.txt)
vim.keymap.set(
  "n",
  "<leader>cP",
  '<cmd>let @+=expand("%:p")<CR>',
  { desc = "copy absolute file path (/something/src/foo.txt)" }
)

-- filename (foo.txt)
vim.keymap.set("n", "<leader>cf", '<cmd>let @+=expand("%:t")<CR>', { desc = "copy file name - (foo.txt)" })

-- directory name (/something/src)
vim.keymap.set(
  "n",
  "<leader>cd",
  '<cmd>let @+=expand("%:p:h")<CR>',
  { desc = "copy directory name - (/something/src)" }
)

-- easy move mapping to move between panes
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left pane' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to below pane' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to above pane' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right pane' })

-- resize panes with the arrow keys (mirrors tmux prefix + H/J/K/L).
-- Ctrl+arrow is used instead of Alt so it works reliably in macOS terminals.
vim.keymap.set('n', '<C-Left>',  '<cmd>vertical resize -2<CR>', { desc = 'Resize pane narrower' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +2<CR>', { desc = 'Resize pane wider' })
vim.keymap.set('n', '<C-Up>',    '<cmd>resize +2<CR>',          { desc = 'Resize pane taller' })
vim.keymap.set('n', '<C-Down>',  '<cmd>resize -2<CR>',          { desc = 'Resize pane shorter' })

-- show current line diagnostics
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "show current line diagnostics" })

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = "Yank block Between ([{}]) " })

-- copilot
-- toggle suggestions
vim.keymap.set("n", "<leader>scp", ":Copilot suggestion toggle_auto_trigger<CR>", { desc = "Copilot toggle suggestions" })

-- buffer management (nvim-bufdel / BufOnly). Bound to <leader>x / <leader>X
-- instead of <leader>b* on purpose: <leader>b is the dap breakpoint toggle, and
-- nesting under it would add a timeoutlen delay before every breakpoint toggle.
vim.keymap.set("n", "<leader>x", "<cmd>BufDel<CR>",       { desc = "close current buffer" })
vim.keymap.set("n", "<leader>X", "<cmd>BufDelOthers<CR>", { desc = "close all buffers except current" })
