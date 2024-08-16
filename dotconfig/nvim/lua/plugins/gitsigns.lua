return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require('gitsigns').setup()
    local gitsigns = require('gitsigns')
    vim.keymap.set("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "[Gitsigns] - toggle line blame" })
    vim.keymap.set("n", "<leader>sb", gitsigns.blame_line, { desc = "[Gitsigns] - Blame line" })
    vim.keymap.set("n", "<leader>sh", gitsigns.preview_hunk, { desc = "[Gitsigns] - Preview Hunk" })
    vim.keymap.set("n", "<leader>sdf", gitsigns.diffthis, { desc = "[Gitsigns] - Diff this" })
    vim.keymap.set("n", "<leader>sn", gitsigns.next_hunk, { desc = "[Gitsigns] - Next Hunk" })
  end
}
