#!/usr/bin/env bash
# update-since-meeting-tui.sh — bring an already-installed machine up to date with the
# meeting-tui batch, without rerunning archdesktopinstall.sh.
#
# Range: 3f308c0..10d0c41, i.e. everything AFTER scripts/update-since-voxtype.sh (which
# stopped at 125c4d3). It adds:
#
#   * custom_software/meeting-tui/ — a Rust/ratatui panel that replaces the Quickshell
#     meeting OSD behind SUPER + SHIFT + M: start/stop/pause a meeting, name it, and browse
#     and export past meetings.
#   * bin_configs/meeting-panel — opens it in a floating foot window and closes any panel
#     already on screen, so the bind and the Waybar voxtype icon always give one fresh
#     window instead of stacking a second one.
#
# What this machine needs: cargo to build the panel, and a reload of Hyprland + Waybar so
# the new bind and the icon pick up the launcher. The voxtype config and models are the
# previous batch's job — run scripts/update-since-voxtype.sh first if this machine predates
# it.
#
#   bash ~/config_files/scripts/update-since-meeting-tui.sh
#
# Idempotent: on an up-to-date machine it just rebuilds (cargo is cached) and reloads.

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
# --ff-only on purpose: if this machine has diverging local commits, better to stop here.
echo "-> Updating $REPO..."
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "WARN: $REPO has uncommitted changes; skipping 'git pull' so nothing is overwritten."
    echo "      Check 'git -C $REPO status' and run 'git -C $REPO pull' yourself."
else
    git -C "$REPO" pull --ff-only
fi

# ==========================================
# 2. DOES THE REPO BRING THE FEATURE?
# ==========================================
missing=()
for f in "custom_software/meeting-tui/Makefile" "bin_configs/meeting-panel"; do
    [ -e "$REPO/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: the repo does not bring the feature; missing:"
    printf '   - %s\n' "${missing[@]}"
    echo "       Update the repo (git -C \"$REPO\" pull) and run this again."
    exit 1
fi

# ==========================================
# 3. REFRESH THE SYMLINKS THE BIND AND THE BAR READ
# ==========================================
# hypr and waybar are already linked on an installed machine; refreshing is cheap and
# guarantees the reload picks up the repo versions.
link_dotconfig() {
    local name="$1"
    local src="$REPO/dotconfig/$name"
    local dest="$HOME/.config/$name"
    [ -d "$src" ] || return 0
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
link_dotconfig hypr
link_dotconfig waybar

# ==========================================
# 4. PACKAGES
# ==========================================
# rust gives cargo (to build the panel); jq is what meeting-panel uses to find and close the
# previous window; foot is the terminal the panel opens in. Missing ones are installed
# before any sudo is asked for, so an up-to-date machine runs in silence.
paquetes=(jq foot)
# Only ask for the Rust package when there is no cargo yet (a rustup toolchain counts too).
command -v cargo > /dev/null 2>&1 || paquetes+=(rust)
faltantes=()
for p in "${paquetes[@]}"; do
    pacman -Qq "$p" > /dev/null 2>&1 || faltantes+=("$p")
done
if [ "${#faltantes[@]}" -eq 0 ]; then
    echo "-> Required packages already present (cargo, jq, foot)."
else
    echo "-> Installing missing packages: ${faltantes[*]}"
    sudo pacman -S --needed --noconfirm "${faltantes[@]}"
fi

# ==========================================
# 5. BUILD THE PANEL
# ==========================================
# The release binary goes to custom_software/meeting-tui/bin/, which is what the bind runs;
# it is machine-specific and not versioned, so it is built here.
echo "-> Building meeting-tui..."
if command -v cargo > /dev/null 2>&1; then
    if make -C "$REPO/custom_software/meeting-tui"; then
        echo "-> meeting-tui built."
    else
        echo "WARN: the build failed; retry with: make -C $REPO/custom_software/meeting-tui"
    fi
else
    echo "WARN: cargo is still missing, so the SUPER+SHIFT+M bind has no binary yet."
    echo "      Install Rust (sudo pacman -S rust, or rustup), then: make -C $REPO/custom_software/meeting-tui"
fi

# ==========================================
# 6. LINK THE BINARIES
# ==========================================
echo "-> Linking bin_configs executables into /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# ==========================================
# 7. RELOAD THE RUNNING SESSION
# ==========================================
if pgrep -x Hyprland > /dev/null 2>&1 && command -v hyprctl > /dev/null 2>&1; then
    echo "-> Reloading Hyprland (the SUPER+SHIFT+M bind / meeting-panel)..."
    hyprctl reload > /dev/null 2>&1 || echo "WARN: hyprctl reload failed."
else
    echo "-> Hyprland is not running in this session; the bind applies on next start."
fi
if pgrep -x waybar > /dev/null 2>&1; then
    echo "-> Reloading Waybar (the voxtype icon opens the new panel)..."
    bash "$REPO/bin_configs/waybar-reload" 2> /dev/null || killall -SIGUSR2 waybar 2> /dev/null || true
else
    echo "-> Waybar is not running; the icon applies when it starts."
fi

echo "---"
echo "=== Machine updated ==="
echo "SUPER+SHIFT+M and the Waybar voxtype icon open meeting-tui; pressing again replaces the"
echo "window instead of stacking a second one."
echo "If this machine has no voxtype models yet, run scripts/update-since-voxtype.sh too."

exit 0
