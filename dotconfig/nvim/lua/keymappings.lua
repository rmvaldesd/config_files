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


--- moving throught the buffers
vim.keymap.set("n", "<leader>h", "<cmd>bprevious<CR>", { desc = "move previous buffer" })
vim.keymap.set("n", "<leader>l", "<cmd>bnext<CR>", { desc = "move next buffer" })

-- show current line diagnostics
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "show current line diagnostics" })

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = "Yank block Between ([{}]) " })

-- copilot
-- toggle suggestions
vim.keymap.set("n", "<leader>scp", ":Copilot suggestion toggle_auto_trigger<CR>", { desc = "Copilot toggle suggestions" })
