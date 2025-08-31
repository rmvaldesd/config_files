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

--- moving throught the panes.
-- vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "move to the right pane" })
-- vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "move to the left pane" })
-- vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "move to the below pane" })
-- vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "move to the above pane" })

--- resizing panes horizontally and vertically.
vim.keymap.set("n", "<M-Up>", ":resize -2<CR>", {})
vim.keymap.set("n", "<M-Down>", ":resize +2<CR>", {})
vim.keymap.set("n", "<M-Left>", ":vertical resize -2<CR>", {})
vim.keymap.set("n", "<M-Right>", ":vertical resize +3<CR>", {})

--- moving throught the buffers
vim.keymap.set("n", "<leader>h", "<cmd>bprevious<CR>", { desc = "move previous buffer" })
vim.keymap.set("n", "<leader>l", "<cmd>bnext<CR>", { desc = "move next buffer" })

-- show current line diagnostics
vim.keymap.set("n", "<leader>sd", vim.diagnostic.open_float, { desc = "show current line diagnostics" })

vim.keymap.set("n", "<leader>yb", "$<S-v>%y", { desc = "Yank block Between ([{}]) " })
