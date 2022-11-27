local home_dir = os.getenv("HOME")
local flutter_path = home_dir .. "/Frameworks/flutter"
local M = {}

-- alternatively you can override the default configs
function M.setup () 
    require("flutter-tools").setup {
    debugger = {
      enabled = true,
      run_via_dap = true,
    },
    outline = { auto_open = false },
    decorations = {
      statusline = { device = true, app_version = true },
    },
    widget_guides = { enabled = true, debug = true },
    dev_log = { enabled = false, open_cmd = "tabedit" },
    lsp = {
      color = {
        enabled = false,
        background = true,
        virtual_text = false,
      },
      settings = {
        showTodos = true,
        renameFilesWithClasses = "prompt",
      },
    },
  }
end

return M
