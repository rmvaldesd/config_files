return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    "nvim-telescope/telescope-file-browser.nvim",
    'nvim-telescope/telescope-fzf-native.nvim',
    "nvim-telescope/telescope-live-grep-args.nvim",

  },

  config = function()
    -- You dont need to set any of these options. These are the default ones. Only
    -- the loading is important
    require('telescope').setup {
      defaults = {
        path_display = {"truncate"},
      },
      extensions = {
        fzf = {
          fuzzy = true,                   -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true,    -- override the file sorter
          case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
          -- the default case_mode is "smart_case"
        }
      },
    }
    -- To get fzf loaded and working with telescope, you need to call
    -- load_extension, somewhere after setup function:
    require('telescope').load_extension("fzf")
    require("telescope").load_extension("file_browser")
    require("telescope").load_extension("flutter")
    require("telescope").load_extension("live_grep_args")
  end
}
