#!/bin/bash
#
# apply-monitor-setup.sh — Agrega la TUI de monitores externos por EDID
# (bin_configs/monitor-setup, bind SUPER+F2) a un equipo que YA instaló el sistema
# con archdesktopinstall.sh, sin volver a correr el instalador completo.
#
#   ./apply-monitor-setup.sh            → pull + paquetes + build + enlaces + plantilla
#   ./apply-monitor-setup.sh --no-pull  → solo local (ya hiciste git pull a mano)
#
# Qué hace, en orden:
#  1. git pull --ff-only de ~/config_files (repo de dotfiles).
#  2. Verifica que el repo ya traiga la herramienta (si no, hay que actualizarlo).
#  3. Asegura el enlace de ~/.config/hypr/hyprland.lua al repo: de ahí salen el bind
#     SUPER+F2, la regla de la ventana flotante y la lectura de ~/.local_host_monitors.
#  4. Instala los paquetes que falten: lua54 (intérprete /usr/bin/lua5.4 + cabeceras)
#     y ncurses. El resto de la cadena (Hyprland, foot, jq, base-devel) ya lo dejó el
#     instalador.
#  5. Compila el binding C de la LTUI vendoreada (bin_configs/ltui/lcurses.so). No
#     está en el repo: es específico de la versión de Lua/ncurses de la máquina.
#  6. Enlaza monitor-setup y monitor-id en /usr/local/bin (scripts/link-bins.sh).
#  7. Crea ~/.local_host_monitors desde la plantilla SOLO si no existe (nunca pisa
#     tus perfiles: ese archivo es el estado local de esta máquina).
#  8. Recarga Hyprland si la sesión está activa.
#
# Idempotente: correrlo varias veces no cambia nada si el estado ya está.
#
# POR QUÉ EXISTE: el instalador (sección 9) ya hace todo esto en equipos nuevos (copió
# la plantilla, enlazó los bins y compiló el binding). Un equipo ya instalado antes de
# esta feature no tiene ni los paquetes de Lua 5.4, ni el .so compilado, ni el archivo
# local de monitores; este script le aplica el cambio sin reinstalar.

set -euo pipefail

REPO="$HOME/config_files"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-monitor-setup.lock"
CFG_DEST="$HOME/.config/hypr/hyprland.lua"
CFG_SRC="$REPO/dotconfig/hypr/hyprland.lua"
MON_TPL="$REPO/templates/local_host_monitors"

do_pull=1
for a in "$@"; do
    case "$a" in
        --no-pull) do_pull=0 ;;
    esac
done

# 0) Un solo proceso a la vez, por si corrés esto desde dos terminales.
exec 9>"$LOCKFILE"
flock -n 9 || { echo "ERROR: otro apply-monitor-setup está corriendo."; exit 1; }

[ -d "$REPO/.git" ] || { echo "ERROR: no encontré el repo en $REPO. Clonalo primero."; exit 1; }

# 1) Traer la versión del repo que trae la herramienta.
if [ "$do_pull" = 1 ]; then
    echo "-> Pull de $REPO (--no-pull para saltar)..."
    git -C "$REPO" pull --ff-only || {
        echo "WARN: el pull falló (¿cambios locales sin commitear?). Sigo con lo que hay."
    }
fi

# 2) ¿El repo ya trae la feature? Si no, el usuario tiene que actualizarlo.
faltan=()
for f in \
    "bin_configs/monitor-setup" \
    "bin_configs/monitor-setup-lib.lua" \
    "bin_configs/monitor-id" \
    "bin_configs/ltui.lua" \
    "bin_configs/ltui/curses.c" \
    "scripts/build-ltui.sh" \
    "templates/local_host_monitors"; do
    [ -e "$REPO/$f" ] || faltan+=("$f")
done
if [ "${#faltan[@]}" -gt 0 ]; then
    echo "ERROR: el repo no trae la herramienta; faltan:"
    printf '   - %s\n' "${faltan[@]}"
    echo "       Actualizá el repo (git -C \"$REPO\" pull) y volvé a correr esto."
    exit 1
fi

# 3) Asegurar el enlace del config de Hyprland (bind SUPER+F2 + regla flotante).
mkdir -p "$HOME/.config/hypr"
if [ -e "$CFG_DEST" ] || [ -L "$CFG_DEST" ]; then
    real="$(realpath "$CFG_DEST" 2>/dev/null || echo "$CFG_DEST")"
    if [ "$real" = "$(realpath "$CFG_SRC")" ]; then
        echo "-> $CFG_DEST ya apunta al repo; sin cambios."
    else
        respaldo="$CFG_DEST.bak.$(date +%Y%m%d%H%M%S)"
        mv "$CFG_DEST" "$respaldo"
        echo "-> Config real encontrada; respaldada como $respaldo"
        ln -s "$CFG_SRC" "$CFG_DEST"
        echo "-> Enlazado: $CFG_DEST -> $CFG_SRC"
    fi
else
    ln -s "$CFG_SRC" "$CFG_DEST"
    echo "-> Enlazado: $CFG_DEST -> $CFG_SRC"
fi

# 4) Paquetes que falten (lua54 = intérprete + cabeceras; ncurses = librería curses).
faltantes=()
for p in lua54 ncurses; do
    pacman -Qq "$p" >/dev/null 2>&1 || faltantes+=("$p")
done
if [ "${#faltantes[@]}" -gt 0 ]; then
    echo "-> Instalando paquetes que faltan: ${faltantes[*]}"
    sudo pacman -S --needed --noconfirm "${faltantes[@]}"
else
    echo "-> lua54 y ncurses ya están instalados."
fi

# 5) Compilar el binding C de la LTUI (lcurses.so). Es rápido e idempotente.
echo "-> Compilando el binding de la LTUI (bin_configs/ltui/lcurses.so)..."
bash "$REPO/scripts/build-ltui.sh"

# 6) Enlazar los ejecutables nuevos en /usr/local/bin (monitor-setup, monitor-id).
echo "-> Enlazando ejecutables de bin_configs en /usr/local/bin..."
bash "$REPO/scripts/link-bins.sh"

# 7) Plantilla de monitores: crear solo si no existe (nunca pisar).
if [ ! -f "$HOME/.local_host_monitors" ]; then
    cp "$MON_TPL" "$HOME/.local_host_monitors"
    echo "-> Creado ~/.local_host_monitors desde la plantilla"
    echo "   Enchufá cada monitor y corré 'monitor-id' para pegar su perfil."
else
    echo "-> ~/.local_host_monitors ya existe; no se sobrescribe (perfiles respetados)."
fi

# 8) Recargar la sesión si Hyprland está corriendo.
if pgrep -x Hyprland >/dev/null 2>&1; then
    if command -v hyprctl >/dev/null 2>&1; then
        echo "-> Recargando Hyprland..."
        hyprctl reload >/dev/null 2>&1 || echo "WARN: hyprctl reload falló."
    fi
else
    echo "-> Hyprland no está corriendo en esta sesión; el bind y la regla se aplican en el próximo inicio."
fi

echo
echo "Listo. Probá con SUPER+F2 (o corré 'monitor-setup' en una terminal)."
