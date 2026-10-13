#!/usr/bin/env bash
# apply-thunar-accels.sh — merge the repo's Thunar keybindings into the user's accels.scm.
#
# Thunar reads ~/.config/Thunar/accels.scm, which GTK AUTO-GENERATES as a dump of its accel
# map. That file cannot simply be symlinked to the repo (GTK rewrites it whenever the user
# changes a shortcut, and the dump includes 100+ commented defaults that are not ours). So
# the repo keeps only the overrides (dotconfig/Thunar/accels-overrides.scm) and this script
# merges them into the user's file.
#
#   bash ~/config_files/scripts/apply-thunar-accels.sh
#
# Idempotent: for each override, it replaces the existing (commented or not) line for that
# ACTION, or appends one when the action is not in the file yet. Running it twice changes
# nothing. Thunar caches the accels at startup, so running instances are told to quit.
#
# Called by archdesktopinstall.sh. Safe to run standalone.

set -euo pipefail

REPO="${HOME}/config_files"
OVERRIDES="$REPO/dotconfig/Thunar/accels-overrides.scm"
ACCELS="${HOME}/.config/Thunar/accels.scm"

[ -f "$OVERRIDES" ] || { echo "ERROR: $OVERRIDES not found; is the repo up to date?" >&2; exit 1; }

# Thunar's config dir is 0700 by default; keep that when creating it.
mkdir -p "$(dirname "$ACCELS")"
chmod 700 "$(dirname "$ACCELS")" 2> /dev/null || true

if [ ! -f "$ACCELS" ]; then
    # No file yet: start from ours. Thunar will pick it up and add its own dump later
    # without dropping our lines, because it re-reads this file on every start.
    printf '; Thunar GtkAccelMap rc-file         -*- scheme -*-\n; this file is an automated accelerator map dump\n;\n' > "$ACCELS"
    echo "-> $ACCELS did not exist; created it from the repo overrides."
fi

# Backup once per run, timestamped (same policy as the rest of the installer).
cp "$ACCELS" "${ACCELS}.bak.$(date +%Y%m%d%H%M%S)"

cambios=0
while IFS= read -r line; do
    # Only the real (uncommented) gtk_accel_path lines carry an override.
    case "$line" in
        '(gtk_accel_path'*) ;;
        *) continue ;;
    esac

    # The ACTION is the first quoted string; that is the key we replace on.
    action=$(printf '%s' "$line" | sed -n 's/^(gtk_accel_path[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -n "$action" ] || continue

    # Escape the action for use in a sed regex (the paths contain '/', so use '|').
    action_re=$(printf '%s' "$action" | sed 's/[][\.^$*+?(){}|]/\\&/g')

    if grep -qE "^;?[[:space:]]*\(gtk_accel_path[[:space:]]*\"${action_re}\"" "$ACCELS"; then
        # Replace whichever form is there (commented default or previous override).
        if ! grep -qxF "$line" "$ACCELS"; then
            sed -i -E "s|^;?[[:space:]]*\(gtk_accel_path[[:space:]]*\"${action_re}\"[^\n]*\)$|${line}|" "$ACCELS"
            cambios=$((cambios + 1))
        fi
    else
        printf '%s\n' "$line" >> "$ACCELS"
        cambios=$((cambios + 1))
    fi
done < "$OVERRIDES"

if [ "$cambios" -eq 0 ]; then
    echo "-> Thunar keybindings already up to date."
else
    echo "-> Thunar keybindings applied ($cambios change(s)); a backup was left next to $ACCELS."
fi

# Thunar reads accels.scm at startup and keeps them in memory; an instance opened before
# this change will not see it. -q quits it (the next open starts fresh).
if pgrep -x thunar > /dev/null 2>&1; then
    echo "-> Restarting Thunar so it picks up the new bindings..."
    thunar -q 2> /dev/null || true
fi

echo "   Go to a path: Ctrl+Shift+G (macOS Cmd+Shift+G) or the stock Ctrl+L / Alt+D."
