# custom_software/

Source for the applications **we write ourselves** — as opposed to `extras/` (installs of
third-party apps) and `suckless/` (vendored upstream source). Each project is a
self-contained directory with its own build.

- **meeting-tui/** — Rust/ratatui panel behind `SUPER + SHIFT + M`: start/stop/pause a
  voxtype meeting, name it, and export past transcripts.

Conventions for a project here:

- its own `Makefile` whose default target builds a release binary into `<project>/bin/`;
- `<project>/bin/` holds the compiled binary (gitignored — it is machine-specific); a
  `.gitkeep` keeps the empty directory in git;
- a `README.md` documenting keys and usage;
- if the desktop launches it, the bind lives in `dotconfig/hypr/hyprland.lua`, and when it
  needs packages or a build step, so does `archdesktopinstall.sh`.
