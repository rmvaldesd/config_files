-- oil.nvim: edit the filesystem like a normal buffer.
-- Open a directory, then create/rename/delete/move files by editing lines and
-- writing with :w. Nothing touches disk until you save, so `u` undoes changes.
--
--   -          open the parent directory of the current file
--   <leader>-  same, but in a floating window
--   <CR>       open the entry under the cursor
--   -          (inside oil) go up one directory
--   g?         show all of oil's buffer-local keys
return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- Load on startup rather than lazily so `nvim <dir>` opens oil instead of netrw.
  lazy = false,
  config = function()
    require("oil").setup({
      -- Take over netrw so `:e .` and `nvim .` land in oil.
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = false,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["<C-h>"] = false, -- keep the pane-navigation maps from keymappings.lua
        ["<C-l>"] = false,
        ["<C-j>"] = false,
        ["<C-k>"] = false,
      },
    })
  end,
  keys = {
    { "-", "<cmd>Oil<CR>", desc = "oil: open parent directory" },
    {
      "<leader>-",
      function()
        require("oil").open_float()
      end,
      desc = "oil: open parent directory (float)",
    },
  },
}
