#!/bin/bash
#
# apply-pdf-reader.sh — Aplica la configuración de lector de PDF (evince como
# predeterminado) sobre un equipo que YA tiene el sistema instalado desde
# archdesktopinstall.sh, sin volver a correr el instalador completo.
#
#   ./apply-pdf-reader.sh           → pull + instalar evince + fijar asociación
#   ./apply-pdf-reader.sh --no-pull → solo local (ya hiciste git pull a mano)
#
# Qué hace, en orden:
#  1. git pull --ff-only de ~/config_files (repo de dotfiles, trae el
#     mimeapps.list actualizado y este mismo script).
#  2. Instala evince (el lector predeterminado nuevo) con sudo pacman. No falla
#     si ya está: --needed no reinstala.
#  3. Se asegura de que ~/.config/mimeapps.list apunte al archivo del repo
#     (copia real vieja -> respaldo con timestamp).
#  4. Fuerza la asociación application/pdf = evince vía xdg-mime, para que el
#     estado que ya está en la sesión coincida con el archivo (Thunar/GLib
#     resuelven por el archivo, pero el cache de xdg-mime vive por aparte).
#
# Idempotente: correrlo varias veces no cambia nada si el estado ya está.

set -euo pipefail

REPO="$HOME/config_files"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-settings.lock"
MIME_DEST="$HOME/.config/mimeapps.list"
MIME_SRC="$REPO/mimeapps.list"

do_pull=1

for a in "$@"; do
    case "$a" in
        --no-pull) do_pull=0 ;;
    esac
done

# 0) Un solo proceso a la vez, por si corrés esto desde dos terminales.
exec 9>"$LOCKFILE"
flock -n 9 || { echo "ERROR: otro apply-pdf-reader está corriendo."; exit 1; }

[ -d "$REPO/.git" ] || { echo "ERROR: no encontré el repo en $REPO. Clonalo primero."; exit 1; }

# 1) Traer el mimeapps.list actualizado y este script.
if [ "$do_pull" = 1 ]; then
    echo "-> Pull de $REPO (--no-pull para saltar)..."
    git -C "$REPO" pull --ff-only || {
        echo "WARN: el pull falló (¿cambios locales sin commitear?). Sigo con lo que hay."
    }
fi

# 2) Instalar evince si hace falta.
if command -v pacman >/dev/null 2>&1; then
    if ! pacman -Q evince >/dev/null 2>&1; then
        echo "-> Instalando evince (pidiendo sudo para pacman)..."
        sudo pacman -S --needed --noconfirm evince
    else
        echo "-> evince ya está instalado."
    fi
else
    echo "WARN: no hay pacman en este sistema; instalá evince a mano."
fi

# 3) Asegurar el enlace de la lista de asociaciones.
mkdir -p "$HOME/.config"
if [ -e "$MIME_DEST" ] || [ -L "$MIME_DEST" ]; then
    real="$(realpath "$MIME_DEST" 2>/dev/null || echo "$MIME_DEST")"
    if [ "$real" = "$(realpath "$MIME_SRC")" ]; then
        echo "-> $MIME_DEST ya apunta al repo; sin cambios."
    else
        respaldo="$MIME_DEST.bak.$(date +%Y%m%d%H%M%S)"
        mv "$MIME_DEST" "$respaldo"
        echo "-> Asociaciones reales encontradas; respaldadas como $respaldo"
        ln -s "$MIME_SRC" "$MIME_DEST"
        echo "-> Enlazado: $MIME_DEST -> $MIME_SRC"
    fi
else
    ln -s "$MIME_SRC" "$MIME_DEST"
    echo "-> Enlazado: $MIME_DEST -> $MIME_SRC"
fi

# 4) Fijar y validar la asociación de PDF con evince.
if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default org.gnome.Evince.desktop application/pdf || true
    actual="$(xdg-mime query default application/pdf 2>/dev/null || echo '(sin respuesta)')"
    echo "-> Handler actual para application/pdf: $actual"
else
    echo "WARN: xdg-mime no está; la asociación queda definida por el mimeapps.list enlazado."
fi

echo "Listo."