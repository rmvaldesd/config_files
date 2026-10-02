#!/usr/bin/env bash
# update-since-voxtype.sh — Bring up to date a machine that was installed BEFORE this
# batch, WITHOUT rerunning archdesktopinstall.sh.
#
# It covers the commits 4b420b0..125c4d3 (the range starts AT 4b420b0, inclusive):
#
#   4b420b0  the Hyprland rebinds (close SUPER+Q, lock SUPER+ESC, session SUPER+CTRL+ESC,
#            fullscreen SUPER+F) and the bigger monitor-setup font,
#   4bd0dd1  the faster find-file (dynamic dot-dir cache exclusions),
#   fca60c8  voxtype meeting mode, the big model and the local summary,
#   afba580  scripts/update.sh (no machine change),
#   ef41057  fast dictation (small model),
#   125c4d3  one shared model + the meeting wrapper + the Waybar status module.
#
# Only the voxtype tail needs packages and models. Everything else is config that rides
# along the existing symlinks (hypr, waybar, bin_configs) and just needs a reload.
#
#   bash ~/config_files/scripts/update-since-voxtype.sh
#
# Idempotent: running it again on an up-to-date machine changes nothing, and it does not
# even ask for sudo when no package is missing.

set -e

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: do not run this as root/sudo; it will ask for sudo only when it needs to."
    exit 1
fi

REPO="$HOME/config_files"
if [ ! -d "$REPO/.git" ]; then
    echo "ERROR: $REPO does not exist (or is not a git repo). Clone it first:"
    echo "       git clone git@github.com:rmvaldesd/config_files.git $REPO"
    exit 1
fi

# ==========================================
# 1. UPDATE THE REPO
# ==========================================
# --ff-only on purpose: if this machine has its own diverging local commits, it is better
# for the script to stop here than to merge histories on its own.
echo "-> Updating $REPO..."
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "WARN: $REPO has uncommitted changes; skipping 'git pull' so nothing is overwritten."
    echo "      Check 'git -C $REPO status' and run 'git -C $REPO pull' yourself."
else
    git -C "$REPO" pull --ff-only
fi

# ==========================================
# 2. DOTCONFIG SYMLINKS
# ==========================================
# hypr and waybar are already linked on an installed machine; voxtype is new in this
# batch (its config moved into the repo). Link any of them that is missing, backing up a
# real directory first, exactly like archdesktopinstall.sh section 9.
link_dotconfig() {
    local name="$1"
    local src="$REPO/dotconfig/$name"
    local dest="$HOME/.config/$name"
    [ -d "$src" ] || return 0
    mkdir -p "$HOME/.config"
    if [ -L "$dest" ]; then
        ln -sfn "$src" "$dest"
    elif [ -e "$dest" ]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        echo "-> $dest already existed; backed up as $backup"
        ln -sfn "$src" "$dest"
    else
        ln -sfn "$src" "$dest"
        echo "-> Linked: $dest -> $src"
    fi
}
link_dotconfig voxtype
link_dotconfig waybar

# ==========================================
# 3. PACKAGES
# ==========================================
# quickshell (extra) is the QML OSD frontend voxtype uses for the meeting panel; wtype is
# what actually types the transcription. voxtype-bin comes from the AUR.
paquetes_pacman=(quickshell wtype)
faltantes=()
for p in "${paquetes_pacman[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || faltantes+=("$p")
done
if [ "${#faltantes[@]}" -eq 0 ]; then
    echo "-> quickshell and wtype are already installed."
else
    echo "-> Installing missing packages: ${faltantes[*]}"
    sudo pacman -S --needed --noconfirm "${faltantes[@]}"
fi

if ! command -v voxtype >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
        echo "-> Installing voxtype-bin from the AUR..."
        yay -S --needed --noconfirm voxtype-bin || \
            echo "WARN: voxtype-bin failed to install; retry later with: yay -S voxtype-bin"
    else
        echo "WARN: voxtype is not installed and yay is missing."
        echo "      Install yay first (archdesktopinstall.sh section 2), then: yay -S voxtype-bin"
    fi
fi

# ==========================================
# 4. VOX TYPE: MODELS + QUICKSHELL OSD + SERVICE
# ==========================================
# The versioned config (dotconfig/voxtype/config.toml, just linked) uses two models:
#   base             dictation (small, multilingual, kept loaded -> instant)
#   large-v3-turbo   meetings (the bin_configs/voxtype-meeting wrapper swaps it in)
# 'setup --download' is idempotent, so it only fetches what is missing.
if command -v voxtype >/dev/null 2>&1; then
    echo "-> Downloading the Whisper models if missing (base, then large-v3-turbo ~1.6 GB)..."
    voxtype setup --download --model base --no-post-install || \
        echo "WARN: could not download 'base'; retry with: voxtype setup --download --model base"
    voxtype setup --download --model large-v3-turbo --no-post-install || \
        echo "WARN: could not download 'large-v3-turbo'; retry with: voxtype setup --download --model large-v3-turbo"

    # The QML tree for the meeting panel and the engine picker is NOT versioned: voxtype
    # copies it from /usr/share/voxtype/quickshell into the user's data dir. Install only
    # when absent so a customized tree is never overwritten (use --force to refresh it).
    qml_dir="${XDG_DATA_HOME:-$HOME/.local/share}/voxtype/quickshell"
    if [ -n "$(ls -A "$qml_dir" 2>/dev/null)" ]; then
        echo "-> Quickshell OSD tree already present at $qml_dir (refresh with: voxtype setup quickshell --force)."
    else
        echo "-> Installing the Quickshell OSD tree..."
        voxtype setup quickshell || \
            echo "WARN: 'voxtype setup quickshell' failed; the meeting panel may not open."
    fi

    echo "-> Enabling and restarting the voxtype user service..."
    systemctl --user enable --now voxtype.service || \
        echo "WARN: could not enable voxtype.service (is there a user systemd session?)."
    systemctl --user restart voxtype.service || \
        echo "WARN: could not restart voxtype.service."
fi

# ==========================================
# 5. LINK THE BINARIES
# ==========================================
# Puts voxtype-meeting, voxtype-state and the refreshed find-file/recent-files in
# /usr/local/bin (the same loop the installer uses).
echo "-> Linking bin_configs executables into /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# ==========================================
# 6. RELOAD THE RUNNING SESSION
# ==========================================
# The binds and the Waybar module come from files that already point at the repo, but the
# running processes keep the old version in memory until they are told to reload.
if pgrep -x waybar >/dev/null 2>&1; then
    echo "-> Reloading Waybar (the custom/voxtype module)..."
    killall -SIGUSR2 waybar || true
else
    echo "-> Waybar is not running; the module will appear when it starts."
fi

if pgrep -x Hyprland >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
    echo "-> Reloading Hyprland (the new keybinds)..."
    hyprctl reload >/dev/null 2>&1 || echo "WARN: hyprctl reload failed."
else
    echo "-> Hyprland is not running in this session; the binds apply on next start."
fi

echo "---"
echo "=== Machine updated ==="
echo "Keybinds:  SUPER+Q close  ·  SUPER+ESC lock  ·  SUPER+CTRL+ESC session menu"
echo "           SUPER+F fullscreen  ·  SUPER+CTRL+SPACE find-file  ·  SUPER+ALT+SPACE recent"
echo "           SUPER+SHIFT+M meeting panel"
echo "Dictation: SUPER+T (base, instant)."
echo "Meetings:  the panel (SUPER+SHIFT+M) or 'voxtype-meeting start' for the big model."
echo "Note: the meeting panel's Start uses the config model (base); use 'voxtype-meeting' for"
echo "      large-v3-turbo. 'voxtype meeting summarize' needs Ollama: sudo pacman -S ollama,"
echo "      then 'sudo systemctl enable --now ollama' and 'ollama pull llama3.2'."

exit 0
