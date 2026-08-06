#!/usr/bin/env bash
# Pone al día un equipo que se instaló ANTES de los commits 73b4739..0c12e72
# (zoom + aceleración VA-API): instala los paquetes que esos commits agregaron
# y repara los enlaces simbólicos que movieron de la raíz del repo a launchers/.
#
# Síntomas de que un equipo necesita esto:
#   - ~/.config/spotify-launcher.conf y ~/.config/teams-for-linux/config.json
#     son symlinks rotos, porque apuntan a ~/config_files/spotify-launcher.conf
#     y ~/config_files/teams-for-linux.config.json (la ubicación VIEJA, antes
#     de que 73b4739 los moviera a launchers/).
#   - No está instalado zoom, ni intel-media-driver, ni libva-utils, porque el
#     equipo se instaló con una versión de archdesktopinstall.sh anterior a
#     esas secciones.
#   - ~/.config/zoomus.conf nunca se tocó (sigue en xwayland=true o no existe).
#
# Uso:
#   bash ~/config_files/scripts/update-since-zoom.sh
#
# Es idempotente: reejecutarlo en un equipo ya al día no cambia nada.

set -e

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: No ejecutes este script como root/sudo. Pedirá sudo sólo cuando lo necesite."
    exit 1
fi

REPO="$HOME/config_files"
if [ ! -d "$REPO/.git" ]; then
    echo "ERROR: no existe $REPO (o no es un repo git). Cloná primero:"
    echo "       git clone git@github.com:rmvaldesd/config_files.git $REPO"
    exit 1
fi

# ==========================================
# 1. ACTUALIZAR EL REPO
# ==========================================
# --ff-only a propósito: si el equipo tiene commits locales propios que
# divergieron, mejor que el script se detenga acá y lo resuelva a mano en vez
# de mezclar historias solo.
echo "-> Actualizando $REPO..."
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "AVISO: $REPO tiene cambios sin commitear; se omite 'git pull' para no pisarlos."
    echo "       Revisá con 'git -C $REPO status' y corré 'git -C $REPO pull' a mano."
else
    git -C "$REPO" pull --ff-only
fi

# ==========================================
# 2. PAQUETES NUEVOS DESDE EL COMMIT DE ZOOM
# ==========================================
echo "-> Instalando paquetes de pacman que faltan (VA-API)..."
paquetes_pacman=(
    intel-media-driver # Driver VA-API para GPUs Intel modernas; decodificación/codificación de video por hardware.
    libva-utils        # vainfo y demás herramientas de diagnóstico de VA-API.
)
sudo pacman -S --needed --noconfirm "${paquetes_pacman[@]}"

echo "-> Instalando zoom desde AUR..."
if ! command -v yay &> /dev/null; then
    echo "AVISO: no está yay instalado; no se puede instalar zoom desde AUR."
    echo "       Instalalo primero (ver archdesktopinstall.sh sección 2) y reintentá con: yay -S zoom"
else
    yay -S --needed --noconfirm zoom || \
        echo "AVISO: falló la instalación de zoom. Reintenta luego con: yay -S zoom"
fi

# ==========================================
# 3. RE-ENLAZAR LOS LAUNCHERS
# ==========================================
# El commit 73b4739 movió spotify-launcher.conf y teams-for-linux.config.json
# de la raíz del repo a launchers/. 'ln -sfn' pisa el destino del enlace sin
# tocar contenido real, así que repara el symlink roto sin pedir nada; si en
# cambio el destino es un archivo real (no symlink), se respalda antes de
# reemplazarlo, igual que hace archdesktopinstall.sh.
relink() {
    local origen="$1" destino="$2"
    if [ -e "$destino" ] && [ ! -L "$destino" ]; then
        local respaldo="${destino}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$destino" "$respaldo"
        echo "-> $destino ya existía y no era symlink; respaldado como $respaldo"
    fi
    ln -sfn "$origen" "$destino"
    echo "-> Enlazado: $destino -> $origen"
}

echo "-> Re-enlazando spotify-launcher.conf y teams-for-linux..."
relink "$REPO/launchers/spotify-launcher.conf" "$HOME/.config/spotify-launcher.conf"

mkdir -p "$HOME/.config/teams-for-linux"
relink "$REPO/launchers/teams-for-linux.config.json" "$HOME/.config/teams-for-linux/config.json"

# El .desktop de teams-for-linux nunca vivió en la raíz (siempre estuvo en
# applications/), pero se re-enlaza igual: si el equipo es de antes de esa
# sección del instalador, hoy directamente le falta.
mkdir -p "$HOME/.local/share/applications"
relink "$REPO/applications/teams-for-linux.desktop" "$HOME/.local/share/applications/teams-for-linux.desktop"

if command -v update-desktop-database > /dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
fi

# ==========================================
# 4. FORZAR ZOOM A WAYLAND NATIVO
# ==========================================
# Zoom es Qt6 y no Electron/CEF: decide el backend con la clave 'xwayland' de
# ~/.config/zoomus.conf, no con un flag ni con QT_QPA_PLATFORM. Ver docs/linux/zoom.md.
# No se enlaza con symlink (a diferencia de arriba): ese archivo es estado
# propio de Zoom (deviceID/MAC, currentMeetingId, email) y Zoom lo reescribe
# entero, así que un symlink metería esos datos al repo. Se ajusta con sed
# sobre el archivo real, o se crea mínimo si Zoom todavía no corrió nunca.
echo "-> Configurando Zoom para Wayland nativo..."
if [ -e "$HOME/.config/zoomus.conf" ]; then
    if grep -q '^xwayland=true' "$HOME/.config/zoomus.conf"; then
        sed -i 's/^xwayland=true/xwayland=false/' "$HOME/.config/zoomus.conf"
        echo "-> ~/.config/zoomus.conf: xwayland puesto en false (Zoom pasa a Wayland nativo)."
    else
        echo "-> ~/.config/zoomus.conf: ya está en Wayland nativo (o sin la clave 'xwayland=true')."
    fi
else
    mkdir -p "$HOME/.config"
    printf '[General]\nxwayland=false\n' > "$HOME/.config/zoomus.conf"
    echo "-> Creado ~/.config/zoomus.conf con xwayland=false."
fi

echo "---"
echo "=== Equipo actualizado ==="
echo "spotify-launcher.conf, teams-for-linux y zoomus.conf ya apuntan a launchers/."
echo "Los flags VA-API de Spotify/Teams y la variable MOZ_ENABLE_WAYLAND de Firefox"
echo "ya estaban dentro de los archivos que 'git pull' actualizó (via los symlinks"
echo "existentes de dotconfig/ y zshrc.local): abrí una terminal nueva o corré"
echo "'source ~/.zshrc' para que la shell actual tome MOZ_ENABLE_WAYLAND."
echo "Cerrá y volvé a abrir Spotify, Teams y Zoom para que tomen sus configs nuevas."

exit 0
