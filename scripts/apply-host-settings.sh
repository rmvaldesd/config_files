#!/bin/bash
#
# apply-host-settings.sh — Aplica la configuración por-máquina (monitores, mouse,
# teclado, efectos) sobre un equipo que YA tiene el sistema instalado desde
# archdesktopinstall.sh, sin volver a correr el instalador completo.
#
#   ./apply-host-settings.sh          → pull + enlazar config + crear settings
#   ./apply-host-settings.sh --no-pull → solo local (ya hiciste git pull a mano)
#   ./apply-host-settings.sh --from RUTA → usar otra plantilla (por defecto la del repo)
#
# Qué hace, en orden:
#  1. git pull --ff-only de ~/config_files (repo de dotfiles).
#  2. Se asegura de que ~/.config/hypr/hyprland.lua apunte al archivo del repo
#     (copia real vieja -> respaldo con timestamp).
#  3. Crea ~/.local_host_settings desde la plantilla del repo SOLO si no existe
#     (nunca pisa uno tuyo: ese archivo es el estado local de esta máquina).
#  4. Recarga Hyprland si la sesión está activa.
#
# Idempotente: correrlo varias veces no cambia nada si el estado ya está.
#
# POR QUÉ EXISTE: el instalador (sección 9) ya hace todo esto en equipos nuevos.
# Un equipo ya instalado antes de esa sección no tiene ni el parser de settings en
# su config ni el archivo local; este script le aplica el cambio sin reinstalar.

set -euo pipefail

REPO="$HOME/config_files"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-settings.lock"
CFG_DEST="$HOME/.config/hypr/hyprland.lua"
CFG_SRC="$REPO/dotconfig/hypr/hyprland.lua"
TPL="$REPO/templates/local_host_settings"

do_pull=1
from="$TPL"

for a in "$@"; do
    case "$a" in
        --no-pull) do_pull=0 ;;
        --from=*)  from="${a#--from=}" ;;
    esac
done

# 0) Un solo proceso a la vez, por si corrés esto desde dos terminales.
exec 9>"$LOCKFILE"
flock -n 9 || { echo "ERROR: otro apply-host-settings está corriendo."; exit 1; }

[ -d "$REPO/.git" ] || { echo "ERROR: no encontré el repo en $REPO. Clonalo primero."; exit 1; }

# 1) Traer la versión de dotfiles que trae el parser de settings + plantilla.
if [ "$do_pull" = 1 ]; then
    echo "-> Pull de $REPO (--no-pull para saltar)..."
    git -C "$REPO" pull --ff-only || {
        echo "WARN: el pull falló (¿cambios locales sin commitear?). Sigo con lo que hay."
    }
fi

# 2) Asegurar el enlace del config de Hyprland.
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

# 3) Crear el archivo de settings local si no existe (nunca pisar).
if [ ! -f "$HOME/.local_host_settings" ]; then
    if [ -f "$from" ]; then
        cp "$from" "$HOME/.local_host_settings"
        echo "-> Creado ~/.local_host_settings desde $from"
        echo "   Editá ese archivo para configurar monitores/mouse/teclado de ESTA máquina;"
        echo "   tus valores NO afectan al otro equipo. Para aplicar cambios: hyprctl reload"
    else
        echo "WARN: no existe la plantilla $from y no hay ~/.local_host_settings;"
        echo "     los defaults de hyprland.lua quedan activos."
    fi
else
    echo "-> ~/.local_host_settings ya existe; no se sobrescribe (respeto ajustes locales)."
fi

# 4) Recargar la sesión si Hyprland está corriendo.
if pgrep -x Hyprland >/dev/null 2>&1; then
    if command -v hyprctl >/dev/null 2>&1; then
        echo "-> Recargando Hyprland..."
        hyprctl reload >/dev/null 2>&1 || echo "WARN: hyprctl reload falló."
    fi
else
    echo "-> Hyprland no está corriendo en esta sesión; los cambios se aplican en el próximo inicio."
fi

echo "Listo."