#!/bin/bash
#
# apply-file-openers.sh — Adds the file openers to a machine that ALREADY installed the
# system with archdesktopinstall.sh, without rerunning the whole installer:
#
#   * find-file      (bind SUPER+CONTROL+SPACE): finds a file under ~ and opens it, and from the
#                    keybind also looks at the clipboard (path or URL, offered on top).
#   * recent-files   (bind SUPER+ALT+SPACE): one rofi menu of recent files (apps, downloads,
#                    screenshots, modified) with per-file actions.
#
#   ./apply-file-openers.sh            → pull + packages + links + reload
#   ./apply-file-openers.sh --no-pull  → local only (you already ran git pull)
#
# What it does, in order:
#  1. git pull --ff-only of ~/config_files (the dotfiles repo).
#  2. Checks the repo already brings the feature (if not, update it).
#  3. Ensures ~/.config/hypr/hyprland.lua links to the repo: the find-file and
#     recent-files binds come from there.
#  4. Installs the packages that are missing: xdg-utils (xdg-open/xdg-mime), glib2
#     (gio), fd, rofi, wl-clipboard, foot, thunar, jq. The rest (Hyprland, coreutils,
#     findutils, util-linux) the installer already left.
#  5. Links find-file and recent-files into /usr/local/bin (scripts/link-bins.sh).
#  6. Reloads Hyprland if the session is active.
#
# Idempotent: running it again changes nothing if the state is already there.
#
# WHY IT EXISTS: the installer (section 9) already does all of this on new machines
# (it links every executable in bin_configs/ and the hypr config). A machine installed
# before this feature lacks the binaries in /usr/local/bin; this applies the change
# without reinstalling.

set -euo pipefail

REPO="$HOME/config_files"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-file-openers.lock"
CFG_DEST="$HOME/.config/hypr/hyprland.lua"
CFG_SRC="$REPO/dotconfig/hypr/hyprland.lua"

do_pull=1
for a in "$@"; do
    case "$a" in
        --no-pull) do_pull=0 ;;
    esac
done

# 0) One process at a time, in case you run this from two terminals.
exec 9>"$LOCKFILE"
flock -n 9 || { echo "ERROR: another apply-file-openers is running."; exit 1; }

[ -d "$REPO/.git" ] || { echo "ERROR: repo not found at $REPO. Clone it first."; exit 1; }

# 1) Bring the repo version that has the feature.
if [ "$do_pull" = 1 ]; then
    echo "-> Pulling $REPO (--no-pull to skip)..."
    git -C "$REPO" pull --ff-only || {
        echo "WARN: pull failed (local uncommitted changes?). Continuing with what is there."
    }
fi

# 2) Does the repo already bring the feature? If not, the user has to update it.
missing=()
for f in \
    "bin_configs/find-file" \
    "bin_configs/recent-files" \
    "scripts/link-bins.sh"; do
    [ -e "$REPO/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: the repo does not bring the feature; missing:"
    printf '   - %s\n' "${missing[@]}"
    echo "       Update the repo (git -C \"$REPO\" pull) and run this again."
    exit 1
fi

# The binds are what call the scripts, so check them in the repo config.
for bind in "find-file" "recent-files"; do
    if ! grep -q "\"$bind\"" "$CFG_SRC"; then
        echo "ERROR: $CFG_SRC does not reference '$bind'. Update the repo and run this again."
        exit 1
    fi
done

# 3) Ensure the Hyprland config link (find-file and recent-files binds).
mkdir -p "$HOME/.config/hypr"
if [ -e "$CFG_DEST" ] || [ -L "$CFG_DEST" ]; then
    real="$(realpath "$CFG_DEST" 2>/dev/null || echo "$CFG_DEST")"
    if [ "$real" = "$(realpath "$CFG_SRC")" ]; then
        echo "-> $CFG_DEST already points to the repo; no change."
    else
        backup="$CFG_DEST.bak.$(date +%Y%m%d%H%M%S)"
        mv "$CFG_DEST" "$backup"
        echo "-> Real config found; backed up as $backup"
        ln -s "$CFG_SRC" "$CFG_DEST"
        echo "-> Linked: $CFG_DEST -> $CFG_SRC"
    fi
else
    ln -s "$CFG_SRC" "$CFG_DEST"
    echo "-> Linked: $CFG_DEST -> $CFG_SRC"
fi

# 4) Packages that are missing.
want=(xdg-utils glib2 fd rofi wl-clipboard foot thunar jq)
missing=()
for p in "${want[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "-> Installing missing packages: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
else
    echo "-> All required packages are already installed."
fi

# 5) Link the new executables into /usr/local/bin (find-file, recent-files).
echo "-> Linking bin_configs executables into /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# 6) Reload the session if Hyprland is running.
if pgrep -x Hyprland >/dev/null 2>&1; then
    if command -v hyprctl >/dev/null 2>&1; then
        echo "-> Reloading Hyprland..."
        hyprctl reload >/dev/null 2>&1 || echo "WARN: hyprctl reload failed."
    fi
else
    echo "-> Hyprland is not running in this session; the binds apply on next start."
fi

echo
echo "Done. Try SUPER+CONTROL+SPACE (paste or type a path/URL) and SUPER+ALT+SPACE (recent files)."
