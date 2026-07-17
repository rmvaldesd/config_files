# Neovim Setup — Complete Usage Guide

Practical reference for **debugging** and **navigating code** with this config.
Leader key is **`<space>`**. Inside Neovim you can also run `:help lsp-nav` for
the code-navigation cheatsheet, or press `<leader>?` for a live key menu.

## Table of Contents

- [1. Prerequisites (install these first)](#1-prerequisites-install-these-first)
- [2. Debugging — shared basics](#2-debugging--shared-basics)
- [3. Debug a Go app](#3-debug-a-go-app)
- [4. Debug a Python script](#4-debug-a-python-script)
- [5. Debug a Django app](#5-debug-a-django-app)
- [6. Debug keymap reference](#6-debug-keymap-reference)
- [7. Code navigation reference](#7-code-navigation-reference)
- [8. Discovering keys / getting help](#8-discovering-keys--getting-help)
- [9. Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites (install these first)

All Go tools live in `$(go env GOPATH)/bin` (usually `~/go/bin`). That directory
**must be on your `PATH`** (already added in `~/.zshrc`).

### Go

```bash
go install golang.org/x/tools/gopls@latest          # LSP server
go install github.com/go-delve/delve/cmd/dlv@latest # debugger
go install golang.org/x/tools/cmd/goimports@latest  # import organizing
go install mvdan.cc/gofumpt@latest                  # formatting
go install honnef.co/go/tools/cmd/staticcheck@latest# extra linting
```

Verify: `gopls version && dlv version`.

### Python / Django

```bash
# per project — install INTO the project's virtualenv:
source .venv/bin/activate
python -m pip install debugpy      # the debugger; REQUIRED
```

- `pyright` (Python LSP) is installed automatically via Mason.
- `debugpy` **must** live in the same virtualenv that runs your app, or
  breakpoints never fire.

### General

- Neovim ≥ 0.11, a Nerd Font (for icons), `git`, `make`, `node` (for some LSPs).
- Plugins install on first launch; run `:Lazy sync` if anything is missing.

---

## 2. Debugging — shared basics

The debug UI, virtual text, and keys are the same for every language.

**The loop:**

1. Open a source file, put the cursor on a line, press **`<leader>b`** to set a
   breakpoint (a red `●` appears in the gutter).
2. Press **`<F5>`** to start. A menu of launch/attach configs appears — pick one.
3. The **dap-ui** opens: scopes/watches/stacks on the left, REPL + console at the
   bottom. Variable values also show **inline at end of line** while stopped.
4. When execution hits a breakpoint, the line is highlighted. Now:
   - **`<F1>`** step into · **`<F2>`** step over · **`<F3>`** step out · **`<F5>`** continue
   - **`<leader>i`** hover a value · **`<leader>de`** evaluate an expression
     (works on a visual selection too) · **`<leader>dr`** open the REPL
5. **`<leader>td`** terminates the session (the UI closes automatically).

See the [full keymap table](#6-debug-keymap-reference).

---

## 3. Debug a Go app

Go debugging works by **attaching** to a headless Delve server (`dlv`).

### Prerequisite

`dlv` installed (see §1). There's a shell alias already defined in `~/.zshrc`:

```bash
alias godbg="dlv debug --headless --listen=:2345 --api-version=2 --accept-multiclient"
```

### A) Debug a running service

1. **Start the app under Delve** from a terminal, pointing at the `main` package:

   ```bash
   cd ~/path/to/go-project
   godbg ./cmd/api          # compiles + runs, Delve listens on :2345
   ```

   (Expand `godbg` = `dlv debug --headless --listen=:2345 --api-version=2 --accept-multiclient`.)

2. In Neovim (same project): set breakpoints, press **`<F5>`**, choose
   **"Attach to Go (regular)"** (connects to `127.0.0.1:2345`).
3. Trigger the code (hit the endpoint / send the request). Execution stops at
   your breakpoint.
4. **`<leader>td`** to detach.

### B) Debug a single test — no manual server needed

1. Put the cursor inside the test function.
2. Press **`<F6>`** (`dap-go`'s "debug test"). It compiles and launches Delve for
   just that test automatically and stops at your breakpoints.

### C) Attach to an already-running binary (by PID)

```bash
dlv attach <pid> --headless --listen=:2345 --api-version=2 --accept-multiclient
```

then `<F5>` → **"Attach to Go (regular)"**.

> The **"Attach to Go (Uber)"** config exists for the Bazel/Uber monorepo (it
> has `substitutePath` mappings for generated code). Use "regular" otherwise.

---

## 4. Debug a Python script

### Prerequisite

`debugpy` installed in the active virtualenv (see §1). **Launch Neovim from the
project root** (after activating the venv) so the correct interpreter is picked:
it resolves `$VIRTUAL_ENV`, then `./.venv/bin/python`, then `./venv/bin/python`.

### Steps

1. Open the `.py` file, set a breakpoint with **`<leader>b`**.
2. Press **`<F5>`** → choose **"Launch file"** (runs the current file), or
   **"Launch file with arguments"** if it needs CLI args.
3. Step and inspect as in §2.

### Debug a Python test

- Put the cursor inside the test and press **`<F5>`** → pick the pytest method
  config (test runner is set to **pytest**).

---

## 5. Debug a Django app

Django needs `--noreload` — its autoreloader forks a child process the debugger
never attaches to, so **without `--noreload` breakpoints silently never fire**.
The bundled config handles this for you.

### Prerequisite

```bash
source .venv/bin/activate
python -m pip install debugpy
```

Then **open Neovim from the project root** (where `manage.py` lives) so the venv
is detected.

### Run & debug the dev server

1. Set breakpoints in a view / serializer / model with **`<leader>b`**.
2. Press **`<F5>`** → choose **"Django: runserver"**.
   - This runs `manage.py runserver --noreload` under the debugger. **You do not
     start `runserver` yourself** — this config launches it.
   - Server output appears in the integrated terminal at the bottom.
3. Hit the endpoint (browser / `curl` / frontend). Execution stops at your
   breakpoint; inspect with `<leader>i`, `<leader>de`, `<leader>dr`.
4. **`<leader>td`** to stop the server + debugger.

### Debug Django tests

- **`<F5>`** → **"Django: test"** (runs `manage.py test` under the debugger;
  breakpoints active in tests and the code they exercise).

### Containerized Django (run the server yourself)

Start it listening for the debugger, then attach from Neovim:

```bash
python -m debugpy --listen 5678 --wait-for-client manage.py runserver --noreload
```

then `<F5>` → **"Attach remote"** (port 5678).

---

## 6. Debug keymap reference

| Key | Action |
|-----|--------|
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Conditional breakpoint (prompts for condition) |
| `<leader>lp` | Log point (prints a message, doesn't stop) |
| `<leader>cb` | Clear all breakpoints |
| `<F5>` | Start / continue |
| `<F6>` | Debug the test under cursor (Go: dap-go) |
| `<F1>` / `<F2>` / `<F3>` | Step into / over / out |
| `<leader>i` | Hover value under cursor |
| `<leader>de` | Evaluate expression (or visual selection) |
| `<leader>dr` | Toggle REPL |
| `<leader>dl` | Run last debug config |
| `<leader>df` | Float the scopes view |
| `<F7>` | Toggle dap-ui (reopen last session view) |
| `<F9>` | Close dap-ui panes |
| `<leader>td` | Terminate session |
| `<leader>dc` | Telescope: pick a debug command |
| `<leader>dB` | Telescope: list all breakpoints |
| `<leader>dv` | Telescope: variables |
| `<leader>dF` | Telescope: stack frames |

---

## 7. Code navigation reference

Full details in `:help lsp-nav`. Highlights:

| Goal | Key |
|------|-----|
| Go to definition / **jump back** | `gd` / `<C-o>` |
| Declaration · implementation · type def | `gD` · `gi` · `<space>D` |
| References (every usage) | `gr` |
| **Callers** (who calls this) | `<leader>fi` |
| **Callees** (what this calls) | `<leader>fo` |
| Symbols in **this file** (outline) | `<leader>fs` |
| Search any symbol **project-wide** | `<leader>fw` |
| Hover doc · signature help | `gh` · `gs` |
| Rename symbol · code action | `<space>rn` · `<space>ca` |
| Toggle inlay hints | `<space>th` |
| Find files · live grep | `<leader>ff` · `<leader>fg` |
| Diagnostics: prev/next/float · all | `<space>dh`/`<space>dn`/`<space>do` · `<leader>fa` |
| Format buffer (conform) | `<leader>l` |

**Core browsing loop:** `gd` to dive into a definition, `<C-o>` to pop back out.
Chain them to tunnel through files and return.

---

## 8. Discovering keys / getting help

You never need to memorize keys — three ways to look them up:

- **`<leader>?`** — which-key popup of the current buffer's mappings (LSP keys).
- **Press a prefix and wait** (e.g. `<space>` or `g`) — which-key lists what
  follows, with descriptions.
- **`<leader>km`** — Telescope: fuzzy-search *every* mapping by description
  (type "callers", "workspace", "rename", "breakpoint"…).
- **`:help lsp-nav`** — the native help doc for navigation.

---

## 9. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Go: LSP/`gopls` not working | Ensure `~/go/bin` on `PATH`; check `:LspInfo` / `:checkhealth vim.lsp`. |
| Go: "connection refused" on attach | The `dlv` headless server isn't running / wrong port. Start `godbg ./cmd/...` first (port 2345). |
| Python/Django: breakpoints never hit | `debugpy` not in the active venv, **or** you didn't use `--noreload` (use the "Django: runserver" config, don't start runserver manually). |
| Python: wrong interpreter | You opened Neovim outside the project / before activating the venv. `cd` in and activate first. |
| `debugpy not found` | Install it into the venv the app runs in: `python -m pip install debugpy`. |
| A plugin seems missing | `:Lazy sync`, then restart. |
| Formatting/imports not applied on save (Go) | `goimports` + `gofumpt` must be installed (see §1). |

---

*Keep this file in sync when you change keymaps in `lua/plugins/`.*
