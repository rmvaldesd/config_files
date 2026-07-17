# Docs

Central documentation hub for this machine's setup: editors, terminal
multiplexer, OS tips, and anything else worth writing down once and finding
fast later.

## Index

| Topic | Location | What's there |
|-------|----------|--------------|
| **Neovim** | [`vim/`](./vim/) | Full setup guide: debugging (Go/Python/Django), LSP navigation, keymaps. |
| **tmux** | [`tmux/`](./tmux/) | Keybindings and options for the current `tmux.conf`. |
| **Linux** | [`linux/`](./linux/) | OS/desktop notes, commands, troubleshooting. |

## Conventions

- One topic per subfolder; each subfolder has its own `README.md` as the entry
  point.
- Prefer Markdown. Keep a table of contents at the top of long docs.
- When you change a config (`tmux.conf`, `lua/plugins/*`, …), update the matching
  doc in the same commit so they don't drift.
- Scratch/throwaway notes still live in `../notes_and_instructions/`; this folder
  is for maintained references.
