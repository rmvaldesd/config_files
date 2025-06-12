return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = false,
        auto_trigger = false
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,   -- overrides default
        terraform = false, -- disallow specific filetype
        go = true,
        javascript = true,
        python = true,
        typescript = true,
        lua = true,
        sh = function()
          if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
            -- disable for .env files
            return false
          end
          return true
        end,
        ["*"] = false -- disallow for all other filetypes
      },
    })
  end,
}
