require("dap").adapters.lldb = {
  type = "executable",
  command = "/usr/bin/lldb-vscode", -- adjust as needed
  name = "lldb",
}

local lldb = {
  name = "Launch lldb",
  type = "lldb", -- matches the adapter
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

require("dap").listeners.after.event_initialized["dapui_config"] = function()
  require("dapui").open()
end
require("dap").listeners.before.event_terminated["dapui_config"] = function()
  require("dapui").close()
end
require("dap").listeners.before.event_exited["dapui_config"] = function()
  require("dapui").close()
end
