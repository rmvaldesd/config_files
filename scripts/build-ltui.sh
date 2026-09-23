#!/usr/bin/env bash
# Build the local LTUI curses binding (bin_configs/ltui/lcurses.so).
#
# LTUI's C module uses the removed Lua 5.1/5.2 helpers luaL_checkint/luaL_optint,
# so it does not build against stock Lua 5.4 headers. We compile a small sed-patched
# copy against the SYSTEM's 5.4 headers (-I/usr/include/lua5.4) and install ncurses.
#
# Needs: gcc, a lua 5.4 dev header package, ncurses. On Arch:
#   sudo pacman -S --needed base-devel ncurses lua54
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin_configs" && pwd)"
SRC="$BIN_DIR/ltui/curses.c"
OUT="$BIN_DIR/ltui/lcurses.so"
WORK="$(mktemp /tmp/curses-patched.XXXXXX.c)"
trap 'rm -f "$WORK"' EXIT

if [ ! -f "$SRC" ]; then
    echo "ERROR: cannot find $SRC" >&2
    exit 1
fi
if ! command -v gcc >/dev/null; then
    echo "ERROR: gcc is required to build the LTUI curses binding" >&2
    exit 1
fi

sed -e 's/luaL_checkint/luaL_checkinteger/g' -e 's/luaL_optint/luaL_optinteger/g' "$SRC" > "$WORK"

if ! gcc -fPIC -shared -O2 -Wno-implicit-function-declaration -I/usr/include/lua5.4 \
        "$WORK" -o "$OUT" -lcurses; then
    echo "ERROR: build failed (is lua 5.4 + ncurses + a C compiler installed?)" >&2
    exit 1
fi

echo "built $OUT"