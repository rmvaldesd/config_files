#!/bin/bash
#
# update.sh — Apply the latest config_files changes to THIS machine: pull the repo,
# re-link the dotfiles and the binaries, and reload the desktop. Idempotent, safe to run
# any time.
#
#   ./update.sh              → pull + link + reload
#   ./update.sh --no-pull    → skip the git pull (you already pulled)
#   ./update.sh --no-reload  → skip the Hyprland reload (you'll do it later)
#
# What it does:
#   1. git pull --ff-only of ~/config_files.
#   2. Link every directory in dotconfig/ into ~/.config. This is DYNAMIC: a new
#      dotconfig/<name> is picked up with no list to edit (the installer's inline loop
#      used to be a hardcoded list).
#   3. Link every executable in bin_configs/ into /usr/local/bin (scripts/link-bins.sh).
#   4. Link the .desktop files (scripts/link-applications.sh).
#   5. Reload Hyprland if the session is active.
#
# What it does NOT do, on purpose: install packages, build the vendored LTUI binding,
# download whisper models, or install Oh-My-Zsh. Those are heavier and per-feature; run
# the matching scripts/apply-*.sh (or archdesktopinstall.sh) when a change needs them.
#
# It only touches symlinks it owns: a real file/dir in ~/.config is backed up once with a
# timestamp before being replaced, exactly like the installer does.

set -euo pipefail

REPO="$HOME/config_files"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/config-files-update.lock"

# Directories that are runtime STATE, not configuration: they must stay real dirs and
# never be symlinked into the repo (the app writes to them). Same idea as the
# 'excluidos' list in link-bins.sh.
exclude_dirs=(herdr)

do_pull=1
do_reload=1
for a in "$@"; do
    case "$a" in
        --no-pull)   do_pull=0 ;;
        --no-reload) do_reload=0 ;;
        *) echo "usage: $0 [--no-pull] [--no-reload]" >&2; exit 1 ;;
    esac
done

# One process at a time, in case you run this from two terminals.
exec 9>"$LOCKFILE"
flock -n 9 || { echo "ERROR: another update is running."; exit 1; }

[ -d "$REPO/.git" ] || { echo "ERROR: repo not found at $REPO. Clone it first."; exit 1; }

# 1) Bring the latest version of the repo.
if [ "$do_pull" = 1 ]; then
    echo "-> Pulling $REPO (--no-pull to skip)..."
    git -C "$REPO" pull --ff-only || {
        echo "WARN: the pull failed (local changes or diverged branch). Continuing with what is there."
    }
fi

# 2) dotconfig/<name> -> ~/.config/<name>, discovered dynamically.
mkdir -p "$HOME/.config"
echo "-> Linking dotconfig/ into ~/.config..."
shopt -s nullglob
for src in "$REPO"/dotconfig/*/; do
    src=${src%/}                      # drop the glob's trailing slash
    name=$(basename -- "$src")

    skip=0
    for e in "${exclude_dirs[@]}"; do
        if [ "$name" = "$e" ]; then skip=1; fi
    done
    if [ "$skip" = 1 ]; then
        echo "   skip: $name (runtime state)"
        continue
    fi

    dest="$HOME/.config/$name"
    if [ -L "$dest" ]; then
        # Already a symlink: repoint it (cheap) so a moved target stays correct.
        ln -sfn "$src" "$dest"
        echo "   $name (symlink refreshed)"
    else
        if [ -e "$dest" ]; then
            backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
            mv "$dest" "$backup"
            echo "   $name: existing config backed up as $(basename -- "$backup")"
        fi
        ln -sfn "$src" "$dest"
        echo "   $name -> repo"
    fi
done
shopt -u nullglob

# 3) bin_configs executables -> /usr/local/bin (asks for sudo).
echo "-> Linking bin_configs executables into /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# 4) .desktop files -> ~/.local/share/applications.
if [ -x "$REPO/scripts/link-applications.sh" ]; then
    echo "-> Linking .desktop files..."
    bash "$REPO/scripts/link-applications.sh"
fi

# 5) Reload the session so the new Hyprland config takes effect.
if [ "$do_reload" = 1 ]; then
    if pgrep -x Hyprland > /dev/null 2>&1; then
        if command -v hyprctl > /dev/null 2>&1; then
            echo "-> Reloading Hyprland..."
            hyprctl reload > /dev/null 2>&1 || echo "WARN: hyprctl reload failed."
        fi
    else
        echo "-> Hyprland is not running in this session; the config applies on next start."
    fi
fi

echo
echo "Done."
echo "Heavier, per-feature steps are NOT applied here. If a change added packages, a"
echo "model, or the LTUI binding, run the matching scripts/apply-*.sh (or the installer)."
