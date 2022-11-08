require('plugins/lsp-settings')

-- GruvBox settings
vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])

-- Airline settings
vim.g.airline_theme = 'dark_minimal'

require("telescope").load_extension "file_browser"


-- Wiki.vim settings

vim.g["wiki_root"] = '~/wiki'
vim.g["wiki_filetypes"] = {'md'} 
vim.g["wiki_index_name"] = 'README'
vim.g["link_extension"] = '.md'
vim.g["link_target_type"] = 'md'
vim.g["mappings_use_defaults"] = 'local'
vim.g["mappings_local"] = {
	['<plug>(wiki-link-follow)'] = '<leader><CR>',
}

