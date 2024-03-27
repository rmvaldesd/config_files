return {
  'mfussenegger/nvim-dap',
  dependencies = { 'leoluz/nvim-dap-go' },
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


    -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
    --[[
require("dap").adapters.delve = {
  type = "server",
  port = "2345",
}

local substitutePath = {
  {
    from = "${env:GOPATH}/src",
    to = "src"
  },
  {
    from = "${env:GOPATH}/bazel-go-code/external/",
    to = "external/"
  },
  {
    from = "${env:GOPATH}/bazel-out/",
    to = "bazel-out/"
  },
  {
    from = "${env:GOPATH}/bazel-go-code/external/go_sdk",
    to = "GOROOT/"
  },
}

require("dap").configurations.go = {
  {
    type = "delve",
    name = "Debug",
    request = "attach",
    mode = "remote",
    substitutePath = substitutePath
  },
  {
    type = "delve",
    name = "Debug test", -- configuration for debugging test files
    request = "attach",
    mode = "test",
    program = "${file}",
    substitutePath = substitutePath
  },
  -- works with go.mod packages and sub packages
  {
    type = "delve",
    name = "Debug test (go.mod)",
    request = "launch",
    mode = "test",
    program = "./${relativeFileDirname}",
    substitutePath = substitutePath,
  }
}
--]]
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

    require("dap-go").setup {
      dap_configurations = {
        {
          -- Must be "go" or it will be ignored by the plugin
          type = "go",
          name = "Attach remote go",
          mode = "remote",
          request = "attach",
        },
      },
      -- delve configurations
      delve = {
        -- the path to the executable dlv which will be used for debugging.
        -- by default, this is the "dlv" executable on your PATH.
        path = "dlv",
        -- time to wait for delve to initialize the debug session.
        -- default to 20 seconds
        initialize_timeout_sec = 20,
        -- a string that defines the port to start delve debugger.
        -- default to string "${port}" which instructs nvim-dap
        -- to start the process in a random available port
        -- port = "${port}",
        port = "2345",
        -- additional args to pass to dlv
        args = {},
        -- the build flags that are passed to delve.
        -- defaults to empty string, but can be used to provide flags
        -- such as "-tags=unit" to make sure the test suite is
        -- compiled during debugging, for example.
        -- passing build flags using args is ineffective, as those are
        -- ignored by delve in dap mode.
        build_flags = "",
        -- whether the dlv process to be created detached or not. there is
        -- an issue on Windows where this needs to be set to false
        -- otherwise the dlv server creation will fail.
        detached = true
      },
    }

    require("dap").listeners.after.event_initialized["dapui_config"] = function()
      require("dapui").open()
    end
    require("dap").listeners.before.event_terminated["dapui_config"] = function()
      require("dapui").close()
    end
    require("dap").listeners.before.event_exited["dapui_config"] = function()
      require("dapui").close()
    end
  end
}
