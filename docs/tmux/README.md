# tmux

Reference for the current [`tmux.conf`](../../tmux.conf). **Prefix is `C-a`**
(Ctrl+a), not the default `C-b`. Press the prefix, release, then the key.

Reload after editing: `prefix + r`.

## Split naming (important)

tmux's `-h`/`-v` flags are counter-intuitive. This config uses the visual model:

- **Vertical split** = panes **side by side** ( `|` divider ) → tmux `-h`
- **Horizontal split** = panes **stacked** ( `—` divider ) → tmux `-v`

New panes/windows always open in the **current pane's directory**.

## Panes

| Keys | Action |
|------|--------|
| `prefix + \|` or `prefix + v` | New pane **vertical** (side by side) |
| `prefix + -` or `prefix + o` | New pane **horizontal** (top / bottom) |
| `prefix + h/j/k/l` | Move to pane left/down/up/right (repeatable) |
| `prefix + H/J/K/L` | Resize pane left/down/up/right by 5 (repeatable, hold Shift) |
| `prefix + q` | Show pane numbers (then press a number to jump) |
| `prefix + z` | Zoom / unzoom current pane (default) |
| `prefix + x` | Kill pane (default) |

*Repeatable (`-r`)* = after the prefix you can press the key several times
without re-pressing the prefix (within the repeat timeout).

## Windows

| Keys | Action |
|------|--------|
| `prefix + c` | New window (current dir) |
| `prefix + n` | Next window (repeatable) |
| `prefix + p` | Previous window (repeatable) |
| `prefix + Tab` | Toggle to last window |
| `prefix + <0-9>` | Jump to window N (default) |
| `prefix + ,` | Rename window (default) |
| `prefix + &` | Kill window (default) |

## Overview — see what exists

| Keys | Action |
|------|--------|
| `prefix + w` | Windows + panes picker (`choose-tree`, zoomed) |
| `prefix + s` | Sessions picker (`choose-tree`, zoomed) |
| `prefix + q` | Pane numbers overlay |
| `prefix + d` | Detach session (default) |

## Project picker (tplm)

| Keys | Action |
|------|--------|
| `prefix + P` | Open `tplm picker` in a floating popup (80%×60%) |

> Moved from `prefix + l` to `prefix + P` so `l` can navigate panes right.
> Ensure `tplm` is on `PATH`. Session scripts: [`../../tmuxp-scripts/`](../../tmuxp-scripts/).

## Options in effect

| Option | Value | Meaning |
|--------|-------|---------|
| `mouse` | on | Click panes/windows, drag borders, scroll. |
| `history-limit` | 10000 | Scrollback lines per pane. |
| `mode-keys` | vi | vi-style keys in copy mode. |
| `set-clipboard` | on | Copy-mode selections sync to the system clipboard. |
| `allow-passthrough` | on | Lets programs emit escape sequences (e.g. image protocols). |
| `display-panes-time` | 2000 | How long the `q` pane-number overlay stays up (ms). |
| `terminal-features` | truecolor + clipboard + cursor shape | 24-bit color and a shaped cursor. |

## Copy mode (vi)

1. `prefix + [` — enter copy mode.
2. Move with `h/j/k/l`, `w`, `b`, `/` to search.
3. `v` to start selection, `y` to yank (→ system clipboard).
4. `q` or `Esc` to exit. `prefix + ]` to paste tmux's buffer.
