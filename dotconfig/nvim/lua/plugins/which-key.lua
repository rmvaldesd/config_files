-- which-key: shows a popup "menu" of available keybindings as you type a prefix.
-- Press <leader> (space) and wait ~300ms, or press `g`, and a menu of every
-- mapping under that prefix appears with its description. This is the fastest
-- way to *discover* keys without memorizing them.
--
-- Extra entry points:
--   <leader>?   -> show buffer-local mappings (LSP keys live here)
--   :WhichKey   -> browse ALL mappings
--   :Telescope keymaps  (<leader>km) -> fuzzy-search every mapping + description
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    -- How long to wait after a prefix before the popup shows (ms).
    delay = 300,
    spec = {
      -- Group labels for your prefixes (leader == <space>).
      { "<leader>f", group = "find / LSP navigation (telescope)" },
      { "<leader>d", group = "debug (dap) / diagnostics" },
      { "<leader>w", group = "workspace folders (LSP)" },
      { "<leader>c", group = "code (action / clear)" },
      { "<leader>t", group = "toggle / terminate" },
      { "<leader>v", group = "visual-selection tools" },
      { "g", group = "goto (LSP navigation)" },
      { "<leader>r", group = "rename / repl" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "which-key: buffer-local mappings (incl. LSP)",
    },
  },
}
