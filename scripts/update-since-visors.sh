#!/usr/bin/env bash
# update-since-visors.sh — bring an already-installed machine up to date with everything
# after the meeting-tui batch, without rerunning archdesktopinstall.sh.
#
# Range: 3f308c0..HEAD beyond what update-since-meeting-tui.sh already covers (that one
# stopped at 10d0c41 / the meeting panel). This script picks up from there:
#
#   6210e09  voxtype starts from the session autostart (SUPER+T did nothing after a reboot)
#   9a8f47e  Waybar restarts on config change instead of the crashing SIGUSR2 reload
#   9ef5a02  meeting-tui table columns + window sizing
#   47a9aa3  meeting-tui fits the monitor (monitor-relative size)
#   14c2aa5  workspaces pinned per monitor + notification when renumbering
#   8a12b71  new-workspace bind (SUPER+CTRL+SHIFT+M/N)
#   0110c05  Quickshell CPU / power-profile visors + the Waybar cpu format fix
#
# What it does: pulls, installs quickshell, links dotconfig/quickshell, links the new
# binaries, and reloads Hyprland + Waybar.
#
#   bash ~/config_files/scripts/update-since-visors.sh
#
# Idempotent: on an up-to-date machine it changes nothing and does not ask for sudo.
#
# Run order on a machine that predates the voxtype or meeting-tui batches:
#   1. scripts/update-since-voxtype.sh
#   2. scripts/update-since-meeting-tui.sh
#   3. scripts/update-since-visors.sh        (this one)

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
# --ff-only on purpose: if this machine has diverging local commits, better to stop here
# than to merge histories on its own.
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
for f in \
    "dotconfig/quickshell/visors/shell.qml" \
    "bin_configs/cpu-visor" \
    "bin_configs/power-visor" \
    "bin_configs/power-profile-state" \
    "bin_configs/new-workspace" \
    "bin_configs/waybar-reload"; do
    [ -e "$REPO/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: the repo does not bring the feature; missing:"
    printf '   - %s\n' "${missing[@]}"
    echo "       Update the repo (git -C \"$REPO\" pull) and run this again."
    exit 1
fi

# ==========================================
# 3. DOTCONFIG SYMLINKS
# ==========================================
# hypr and waybar are already linked on an installed machine; the refresh is cheap and makes
# sure the reload below picks up the repo versions. quickshell is new in this batch, so it
# may not exist yet.
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
link_dotconfig hypr
link_dotconfig waybar
link_dotconfig quickshell

# ==========================================
# 4. PACKAGES
# ==========================================
# quickshell hosts the CPU and power-profile visors, and it is also the frontend the voxtype
# dictation OSD is configured to use. computed only when something is missing, so an
# up-to-date machine never gets interrupted for a password.
if pacman -Qq quickshell > /dev/null 2>&1; then
    echo "-> quickshell is already installed."
else
    echo "-> Installing quickshell..."
    sudo pacman -S --needed --noconfirm quickshell
fi

# ==========================================
# 5. LINK THE BINARIES
# ==========================================
# cpu-visor, power-visor, power-profile-state, new-workspace and the refreshed
# voxtype-state / meeting-panel all land in /usr/local/bin here. The Waybar modules and the
# Hyprland binds call some of them by bare name, so this step is not optional.
echo "-> Linking bin_configs executables into /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# ==========================================
# 6. RELOAD THE RUNNING SESSION
# ==========================================
# The bar carries the new modules (custom/power-profile, the cpu format fix) and the binds
# come from hyprland.lua, so both processes have to re-read their config.
if pgrep -x waybar > /dev/null 2>&1; then
    echo "-> Restarting Waybar (new modules and the cpu format fix)..."
    # Not SIGUSR2: on waybar 0.15 that reload path aborts (Waybar #3546). The helper kills
    # the bar and the supervisor in auto-reload.sh brings it back.
    bash "$REPO/bin_configs/waybar-reload" 2> /dev/null || killall waybar 2> /dev/null || true
else
    echo "-> Waybar is not running; the modules apply when it starts."
fi

if pgrep -x Hyprland > /dev/null 2>&1 && command -v hyprctl > /dev/null 2>&1; then
    echo "-> Reloading Hyprland (new binds and the visors autostart)..."
    hyprctl reload > /dev/null 2>&1 || echo "WARN: hyprctl reload failed."
else
    echo "-> Hyprland is not running in this session; the binds apply on next start."
fi

echo "---"
echo "=== Machine updated ==="
echo "CPU and power-profile: click those two Waybar modules to open the Quickshell visors"
echo "  (the visor daemon starts at login; to start it now: qs -n -c visors -d)."
echo "Workspaces: SUPER+CTRL+SHIFT+M/N create one next to the current one;"
echo "            SUPER+CTRL+M renumbers to 1..N."
echo "If SUPER+T did nothing after a reboot on this machine, that is fixed here: voxtype now"
echo "starts from the session autostart. Note it applies on the NEXT login."

exit 0
