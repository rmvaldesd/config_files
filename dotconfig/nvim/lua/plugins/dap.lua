return {
  'mfussenegger/nvim-dap',
  config = function()
    require("dap").adapters.lldb = {
      type = "executable",
      command = "/usr/bin/lldb-vscode", -- adjust as needed
      name = "lldb",
    }

    local lldb = {
      name = "Launch lldb",
      type = "lldb",      -- matches the adapter
      request = "launch", -- could also attach to a currently running process
      program = function()
        return vim.fn.input(
          "Path to executable: ",
          vim.fn.getcwd() .. "/",
          "file"
        )
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = false,
    }

    require('dap').configurations.rust = {
      lldb -- different debuggers or more configurations can be used here
    }


    -- Go Uber Configuration
    -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
    require("dap").adapters.delve = {
      type = 'server',
      port = 2345,
    }
    require("dap").configurations.go = {
      {
        name = 'Attach to Go (Uber)',
        type = 'delve',
        request = 'attach',
        mode = 'remote',
        stopOnEntry = true,
        substitutePath = {
          {
            from =
            "${env:WORKSPACE_ROOT}/src/code.uber.internal/devexp/green-keeper/controller/dependency/repo_insights.go",
            to =
            "bazel-out/k8-dbg/bin/src/code.uber.internal/devexp/green-keeper/controller/dependency/cff_/repo_insights_cffgen.go",
          },
          {
            from = "${env:WORKSPACE_ROOT}/src",
            to = "src",
          },
          {
            from = "${env:WORKSPACE_ROOT}/bazel-go-code/external/",
            to = "external/",
          },
          {
            from = "${env:WORKSPACE_ROOT}/bazel-out/",
            to = "bazel-out/",
          },
          {
            from = "${env:WORKSPACE_ROOT}/bazel-go-code/external/go_sdk",
            to = "GOROOT/",
          },
        },
      },
    }
    -- Go Uber Configuration End

    -- Flutter configuration
    require("dap").adapters.dart = {
      type = "executable",
      -- As of this writing, this functionality is open for review in https://github.com/flutter/flutter/pull/91802
      command = "flutter",
      args = { "debug_adapter" }
    }
    require("dap").configurations.dart = {
      {
        type = "dart",
        request = "launch",
        name = "Launch Flutter Program",
        -- The nvim-dap plugin populates this variable with the filename of the current buffer
        program = "${file}",
        -- The nvim-dap plugin populates this variable with the editor's current working directory
        cwd = "${workspaceFolder}",
        -- This gets forwarded to the Flutter CLI tool, substitute `linux` for whatever device you wish to launch
        toolArgs = { "-d", "iphone 14" }
      }
    }
    -- Flutter configuration End

    require("dap").listeners.after.event_initialized["dapui_config"] = function()
      require("dapui").open()
    end
    require("dap").listeners.before.event_terminated["dapui_config"] = function()
      require("dapui").close()
    end
    require("dap").listeners.before.event_exited["dapui_config"] = function()
      require("dapui").close()
    end


    --- dap mappings
    local dap_ok, dap = pcall(require, "dap")
    local dap_ui_ok, ui = pcall(require, "dapui")

    if not (dap_ok and dap_ui_ok) then
      require("notify")("nvim-dap or dap-ui not installed!", "warning") -- nvim-notify is a separate plugin, I recommend it too!
      return
    end

    vim.fn.sign_define('DapBreakpoint', { text = 'X' })

    -- Set breakpoints, get variable values, step into/out of functions, etc.
    vim.keymap.set("n", "<leader>i", require("dap.ui.widgets").hover, { desc = '[dap] - hover information' })
    vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = '[dap] - toggle [b]reakpoints' })
    vim.keymap.set("n", "<leader>B",
      function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      { desc = '[dap] - condition [B]reakpoint' }
    )
    vim.keymap.set("n", "<F5>", dap.continue, { desc = '[dap] - continue / start debugging' })
    vim.keymap.set("n", "<F1>", dap.step_into, { desc = '[dap] - debugging step into' })
    vim.keymap.set("n", "<F2>", dap.step_over, { desc = '[dap] - debugging step over' })
    vim.keymap.set("n", "<F3>", dap.step_out, { desc = '[dap] - debugging step out' })
    vim.keymap.set("n", "<F7>", ui.toggle, { desc = '[dap] - see last session result.' })
    vim.keymap.set("n", "<leader>td", dap.terminate, { desc = '[dap] - terminate debugging' })
    -- vim.keymap.set("n", "<leader>dg", require("dap-go").debug_test, { desc = '[dap] - debug go current test' })
    vim.keymap.set("n", "<leader>cb", function()
      dap.clear_breakpoints()
      require("notify")("Breakpoints cleared", "warn")
    end, { desc = '[dap] - [c]lear [b]reakpoints' })
  end
}
