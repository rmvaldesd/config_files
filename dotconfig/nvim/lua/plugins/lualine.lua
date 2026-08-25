return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('lualine').setup({
      options = {
        theme = 'kanagawa',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'window', 'lsp_status', 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {}
      },
      -- Top bar (buffer list). Toggle it with <leader>tb -- see keymappings.lua.
      tabline = {
        lualine_a = {
          {
            'buffers',
            mode = 2,                  -- show buffer name + number
            show_filename_only = true,
            hide_filename_extension = false,
            show_modified_status = true,
            symbols = { modified = ' ●', alternate_file = '', directory = ' ' },
          },
        },
        lualine_z = { { 'tabs', mode = 2 } },
      },
      extensions = {}
    })
  end

}
