# meeting-tui

A ratatui (Rust) front-end for **voxtype meeting recording**. It replaces the old
Quickshell meeting panel behind `SUPER + SHIFT + M`:

- **Start / stop / pause / resume** a meeting without typing `voxtype meeting ...`.
- **Name the meeting** before starting; the name gets a `YYYY-MM-DD HH:MM:SS` timestamp
  appended so two meetings never look alike. Leave it empty and it becomes
  `Meeting <timestamp>`.
- While idle, **list saved meetings** and **export** the selected one (markdown / text /
  json) into a folder you pick. Default: `~/meeting-transcriptions`.

## Build

```sh
cd ~/config_files/custom_software/meeting-tui
make            # release build -> bin/meeting-tui
```

Other targets: `make build` (debug), `make run`, `make check`, `make fmt`, `make clean`.
The toolchain is whatever `cargo` is on `PATH` (rustup or the `rust` package).

## Keys

| Context | Key | Action |
| --- | --- | --- |
| List | `s` | Start a meeting (asks for a name) |
| List | `↑`/`↓`, `k`/`j` | Move the selection |
| List | `e` / `Enter` | Export the selected meeting |
| List | `o` | Open the export folder |
| List | `O` | Open the selected meeting's voxtype folder |
| List | `c` | Open the configuration screen |
| List | `r` | Refresh the list |
| List | `q` / `Esc` | Quit |
| Config | `↑`/`↓`, `k`/`j` | Move between options |
| Config | `Enter` / `Space` | Change the value (cycle format, toggle, edit folder) |
| Config | `Esc` / `q` / `c` | Back to the list |
| Meeting | `p` | Pause / resume |
| Meeting | `x` | Stop and transcribe |
| Meeting | `q` / `Esc` | Close the window (recording continues) |

## Notes

- Settings live in `~/.config/meeting-tui/config.toml` (export folder, format, flags). It
  is machine-local and intentionally not part of the repo.
- Past meetings are read straight from `~/.local/share/voxtype/meetings/*/metadata.json`;
  export shells out to `voxtype meeting export`.
- Opening folders uses `xdg-open` (from `xdg-utils`).
