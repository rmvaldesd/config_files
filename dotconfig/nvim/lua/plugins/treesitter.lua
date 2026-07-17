return {
  "nvim-treesitter/nvim-treesitter",
  -- Force lazy to use the new branch just in case
  branch = "main",
  build = ":TSUpdate",
  config = function()
    -- The new top-level module is just 'nvim-treesitter'
    local ts = require("nvim-treesitter")

    -- Define the languages you want to automatically track
    local ensure_installed = {
      "c",
      "lua",
      "vim",
      "vimdoc",
      "query",
      "markdown",
      "python",
      "go",
      "gomod",
      "gosum",
      "gowork",
      "gotmpl",
      "dart",
      "rust",
      "json",
      "tsx",
      "html",
      "toml",
    }

    -- In the new API, we fetch what's installed and pass the remainder to .install()
    local installed = require("nvim-treesitter.config").get_installed()
    local to_install = {}
    for _, lang in ipairs(ensure_installed) do
      if not vim.tbl_contains(installed, lang) then
        table.insert(to_install, lang)
      end
    end

    if #to_install > 0 then
      ts.install(to_install)
    end
  end,
  init = function()
    -- The new rewrite handles parser management, but leaves activation to Neovim core.
    -- This autocmd handles lightning-fast native syntax highlighting and indentation.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        pcall(vim.treesitter.start)
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}

--      ensure_installed = {
--        "c",
--        "lua",
--        "vim",
--        "help",
--        "query",
--        "go",
--        "dart",
--        "python",
--        "tsx",
--        "toml",
--        "yaml",
--        "json",
--        "html",
--      },
