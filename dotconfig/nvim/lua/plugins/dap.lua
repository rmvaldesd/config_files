return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "leoluz/nvim-dap-go",
  },
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
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = false,
    }

    require("dap").configurations.rust = {
      lldb, -- different debuggers or more configurations can be used here
    }

    -- Go Uber Configuration
    -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
    require("dap").adapters.delve = {
      type = "server",
      port = 2345,
    }
    require("dap").configurations.go = {
      {
        name = "Attach to Go (Uber)",
        type = "delve",
        request = "attach",
        mode = "remote",
        -- stopOnEntry = true,
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
      {
        name = "Attach to Go (regular)",
        type = "delve",
        request = "attach",
        mode = "remote",
        host = "127.0.0.1", -- ADD THIS
        port = 2345,        -- ADD THIS
        -- stopOnEntry = true,
      },
    }
    -- Go Uber Configuration End

    -- Flutter configuration
    require("dap").adapters.dart = {
      type = "executable",
      -- As of this writing, this functionality is open for review in https://github.com/flutter/flutter/pull/91802
      command = "flutter",
      args = { "debug_adapter" },
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
        toolArgs = { "-d", "iphone 14" },
      },
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

    -- Breakpoint / stopped-line signs. Highlight the whole stopped line so the
    -- current execution point is obvious at a glance.
    vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
    vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
    vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticWarn", linehl = "DapStoppedLine", numhl = "DiagnosticWarn" })

    -- DAP-GO CONFIGURATION.
    -- This is used mostly for the "debug this test" feature.
    -- https://github.com/leoluz/nvim-dap-go
    require("dap-go").setup({
      dap_configurations = {
        {
          -- Must be "go" or it will be ignored by the plugin
          type = "go",
          name = "Attach remote - (dap-go)",
          mode = "remote",
          request = "attach",
        },
      },
      -- delve configurations
      delve = {
        path = "dlv",
        initialize_timeout_sec = 20,
        port = "${port}",
        -- additional args to pass to dlv
        args = {},
        build_flags = {},
        detached = vim.fn.has("win32") == 0,
        cwd = nil,
      },
      tests = {
        -- enables verbosity when running the test.
        verbose = false,
      },
    })

    -- Python debugging. nvim-dap-python was already installed but never wired up.
    -- debugpy must live in the SAME interpreter that runs your app: activate the
    -- project's venv, then `python -m pip install debugpy`.
    --
    -- Resolve the interpreter: prefer an active/project virtualenv, fall back to
    -- system python3. dap-python also re-resolves the venv per-launch for the
    -- debugged program, so opening nvim at the project root is enough.
    local function python_path()
      local venv = os.getenv("VIRTUAL_ENV")
      if venv and vim.fn.executable(venv .. "/bin/python") == 1 then
        return venv .. "/bin/python"
      end
      local cwd = vim.fn.getcwd()
      for _, p in ipairs({ cwd .. "/.venv/bin/python", cwd .. "/venv/bin/python" }) do
        if vim.fn.executable(p) == 1 then
          return p
        end
      end
      return "python3"
    end

    local ok_dap_python, dap_python = pcall(require, "dap-python")
    if ok_dap_python then
      dap_python.setup(python_path())
      dap_python.test_runner = "pytest"

      -- Django-specific launch configs. `--noreload` is REQUIRED: Django's
      -- autoreloader runs the server in a child process the debugger never
      -- attaches to, so without it breakpoints silently never fire.
      table.insert(dap.configurations.python, 1, {
        type = "python",
        request = "launch",
        name = "Django: runserver",
        program = "${workspaceFolder}/manage.py",
        args = { "runserver", "--noreload" },
        django = true,          -- enables Django template breakpoints
        justMyCode = false,     -- allow stepping into Django/3rd-party code
        console = "integratedTerminal",
      })
      table.insert(dap.configurations.python, 2, {
        type = "python",
        request = "launch",
        name = "Django: test",
        program = "${workspaceFolder}/manage.py",
        args = { "test" },
        django = true,
        justMyCode = false,
        console = "integratedTerminal",
      })
    end

    -- Set keymappings
    vim.keymap.set("n", "<leader>i", require("dap.ui.widgets").hover, { desc = "[dap] - hover information" })
    vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "[dap] - toggle [b]reakpoints" })
    vim.keymap.set("n", "<leader>B", function()
      dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, { desc = "[dap] - condition [B]reakpoint" })

    vim.keymap.set("n", "<leader>lp", function()
      vim.ui.input({ prompt = "log point message: " }, function(input)
        if input then
          require("dap").set_breakpoint(nil, nil, input)
        end
      end)
    end, { desc = "[dap] Set log point" })

    vim.keymap.set("n", "<F5>", dap.continue, { desc = "[dap] - continue / start debugging" })
    vim.keymap.set("n", "<F6>", require("dap-go").debug_test, { desc = "[dap] - debug test" })
    vim.keymap.set("n", "<F1>", dap.step_into, { desc = "[dap] - debugging step into" })
    vim.keymap.set("n", "<F2>", dap.step_over, { desc = "[dap] - debugging step over" })
    vim.keymap.set("n", "<F3>", dap.step_out, { desc = "[dap] - debugging step out" })
    vim.keymap.set("n", "<F7>", ui.toggle, { desc = "[dap] - see last session result." })
    vim.keymap.set("n", "<leader>td", dap.terminate, { desc = "[dap] - terminate debugging" })
    vim.keymap.set("n", "<F9>", ui.close, { desc = "[dap] - close debug panes" })

    vim.keymap.set("n", "<leader>cb", function()
      dap.clear_breakpoints()
      require("notify")("Breakpoints cleared", "warn")
    end, { desc = "[dap] - [c]lear [b]reakpoints" })

    -- Evaluate the expression under the cursor (normal) or the visual selection.
    vim.keymap.set({ "n", "v" }, "<leader>de", function()
      ui.eval(nil, { enter = true })
    end, { desc = "[dap] - [e]valuate expression" })
    vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "[dap] - toggle [r]epl" })
    vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "[dap] - run [l]ast config" })
    vim.keymap.set("n", "<leader>df", function()
      ui.float_element("scopes", { enter = true })
    end, { desc = "[dap] - [f]loat scopes" })
  end,
}
