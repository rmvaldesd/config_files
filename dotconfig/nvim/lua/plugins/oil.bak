return {
  'stevearc/oil.nvim',
  dependencies = {
    'echasnovski/mini.nvim',
  },
  config = function()
    require("oil").setup()
    vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

    -- open parent directory in a float window
    vim.keymap.set("n", "<space>-", require("oil").toggle_float, { desc = "Open parent directory in a float window" })
  end
}
