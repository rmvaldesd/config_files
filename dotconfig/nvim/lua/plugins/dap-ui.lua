return {
  "rcarriga/nvim-dap-ui",
  dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
  config = function()
    require("dapui").setup({
      icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
      controls = {
        enabled = true,
        element = "repl",
        icons = {
          pause = "",
          play = "",
          step_into = "",
          step_over = "",
          step_out = "",
          step_back = "",
          run_last = "",
          terminate = "",
          disconnect = "",
        },
      },
      floating = {
        max_height = 0.9,
        max_width = 0.5,
        border = "rounded",
        mappings = { close = { "q", "<Esc>" } },
      },
      layouts = {
        {
          -- Left sidebar: scopes, breakpoints, stacks, watches.
          elements = {
            { id = "scopes", size = 0.35 },
            { id = "watches", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "breakpoints", size = 0.15 },
          },
          size = 50,
          position = "left",
        },
        {
          -- Bottom tray: REPL + program console.
          elements = {
            { id = "repl", size = 0.5 },
            { id = "console", size = 0.5 },
          },
          size = 12,
          position = "bottom",
        },
      },
    })
  end,
}
