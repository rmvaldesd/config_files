# CodeDiff Plugin Tutorial

Quick reference for `esmuellert/codediff.nvim`.

## Basic usage

Open any two files side-by-side:

```vim
:CodeDiff file1.txt file2.txt
```

Or diff against a git revision:

```vim
:CodeDiff HEAD~1
```

Or diff against a branch (e.g. `main` or `master`):

```vim
:CodeDiff main
:CodeDiff master
```

## Key bindings (in the diff view)

| Key               | Action                          |
|-------------------|--------------------------------|
| `]c` / `[c`       | Next / previous hunk           |
| `]f` / `[f`       | Next / previous file           |
| `-`               | Stage / unstage current hunk   |
| `<leader>hs`      | Stage hunk                     |
| `<leader>hu`      | Unstage hunk                   |
| `<leader>hr`      | Discard hunk                   |
| `t`               | Toggle side-by-side ↔ unified layout |
| `gc`              | Toggle compact mode            |
| `q`               | Quit                           |

## Explorer (file list)

Inside the diff view press `<leader>e` to focus the file explorer pane, then:

| Key   | Action          |
|-------|-----------------|
| `<CR>` | Select file    |
| `S`   | Stage all       |
| `U`   | Unstage all     |
| `R`   | Refresh         |

## Merge conflict resolution

| Key          | Action                 |
|--------------|------------------------|
| `<leader>ct` | Accept incoming        |
| `<leader>co` | Accept current         |
| `<leader>cb` | Accept both            |
| `<leader>cx` | Discard                |
| `]x` / `[x`  | Next / previous conflict |

## Example workflow

```bash
# 1. Open diff view against main
:CodeDiff main

# 2. Browse hunks with ]c and [c
# 3. Toggle layout with t
# 4. Stage a hunk with -
# 5. Quit with q
```