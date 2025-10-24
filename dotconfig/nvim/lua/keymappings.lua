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

-- Paso PEQUEÑO (1 unidad)
vim.keymap.set('n', '<M-h>', ':vertical resize -1<CR>', { silent = true, desc = 'Narrow left (small)' })
vim.keymap.set('n', '<M-l>', ':vertical resize +1<CR>', { silent = true, desc = 'Widen right (small)' })
vim.keymap.set('n', '<M-j>', ':resize +1<CR>', { silent = true, desc = 'Increase height (small)' })
vim.keymap.set('n', '<M-k>', ':resize -1<CR>', { silent = true, desc = 'Decrease height (small)' })

-- Paso NORMAL (5 unidades)
vim.keymap.set('n', '<M-H>', ':vertical resize -5<CR>', { silent = true, desc = 'Narrow left (normal)' })
vim.keymap.set('n', '<M-L>', ':vertical resize +5<CR>', { silent = true, desc = 'Widen right (normal)' })
vim.keymap.set('n', '<M-J>', ':resize +5<CR>', { silent = true, desc = 'Increase height (normal)' })
vim.keymap.set('n', '<M-K>', ':resize -5<CR>', { silent = true, desc = 'Decrease height (normal)' })

--- moving throught the buffers
vim.keymap.set("n", "<leader>h", "<cmd>bprevious<CR>", { desc = "move previous buffer" })
vim.keymap.set("n", "<leader>l", "<cmd>bnext<CR>", { desc = "move next buffer" })

-- show current line diagnostics
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "show current line diagnostics" })

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = "Yank block Between ([{}]) " })

-- copilot
-- toggle suggestions
vim.keymap.set("n", "<leader>scp", ":Copilot suggestion toggle_auto_trigger<CR>", { desc = "Copilot toggle suggestions" })
