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

-- map('n', '<C-l>', '<cmd>noh<CR>')    -- Clear highlights
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
map("n", "<leader>fc", "<cmd>Telescope flutter commands<CR>")
map("n", "gr", "<cmd>Telescope lsp_references<CR>")
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

--- moving throught the panes.
map('n', '<C-l>', '<C-w>l', {})
map('n', '<C-h>', '<C-w>h', {})
map('n', '<C-k>', '<C-w>k', {})
map('n', '<C-j>', '<C-w>j', {})

--- moving throught the buffers
map('n', '<leader>h', '<cmd>bprevious<CR>', {})
map('n', '<leader>l', '<cmd>bnext<CR>', {})

--- Persevim (Nerdtree / TagBar)
map('n', '<leader>m', '<cmd>NERDTreeToggle<CR>', {})
map('n', '<leader>n', '<cmd>TagbarToggle<CR>', {})


--- dap mappings
local dap_ok, dap = pcall(require, "dap")
local dap_ui_ok, ui = pcall(require, "dapui")

if not (dap_ok and dap_ui_ok) then
  require("notify")("nvim-dap or dap-ui not installed!", "warning") -- nvim-notify is a separate plugin, I recommend it too!
  return
end

vim.fn.sign_define('DapBreakpoint', { text = '🐞' })

-- Start debugging session
vim.keymap.set("n", "<localleader>ds", function()
  dap.continue()
  ui.toggle({})
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false) -- Spaces buffers evenly
end)

-- Set breakpoints, get variable values, step into/out of functions, etc.
vim.keymap.set("n", "<leader>dl", require("dap.ui.widgets").hover)
vim.keymap.set("n", "<leader>dc", dap.continue)
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint)
vim.keymap.set("n", "<leader>dn", dap.step_over)
vim.keymap.set("n", "<leader>di", dap.step_into)
vim.keymap.set("n", "<leader>do", dap.step_out)
vim.keymap.set("n", "<leader>dC", function()
  dap.clear_breakpoints()
  require("notify")("Breakpoints cleared", "warn")
end)

-- Close debugger and clear breakpoints
vim.keymap.set("n", "<leader>de", function()
  dap.clear_breakpoints()
  ui.toggle({})
  dap.terminate()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>=", false, true, true), "n", false)
  require("notify")("Debugger session ended", "warn")
end)

