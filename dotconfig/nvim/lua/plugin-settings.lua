require('plugins/lsp-settings')

-- GruvBox settings
vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])

-- Airline settings
vim.g.airline_theme = 'dark_minimal'

require("telescope").load_extension "file_browser"

