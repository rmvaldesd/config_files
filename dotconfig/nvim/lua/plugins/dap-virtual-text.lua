return {
  "theHamsta/nvim-dap-virtual-text",
  dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("nvim-dap-virtual-text").setup({
      enabled = true,
      -- Show virtual text for the current stack frame's variables inline.
      commented = false,
      show_stop_reason = true,
      -- Highlight changed values in red (uses the `NvimDapVirtualTextChanged` hl).
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      -- Display eval results from `:DapVirtualTextForceRefresh` / hover inline.
      all_frames = false,
      virt_text_pos = "eol", -- put the value at end of line to avoid shifting code
    })
  end,
}
