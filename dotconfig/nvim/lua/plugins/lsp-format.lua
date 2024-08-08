return {
  -- Formatting
  'lukas-reineke/lsp-format.nvim',
  config = function()
    require("lsp-format").setup {
      exclude = { "jsonls", "gopls" },
    }
  end
}
