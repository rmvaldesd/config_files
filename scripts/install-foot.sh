#!/usr/bin/env bash
# Instala foot terminal y aplica la configuracion versionada en config_files.
# En Arch lo invoca archdesktopinstall.sh (secciones 4 y 9); para reinstalar
# o actualizar la config a mano:
#   bash ~/config_files/scripts/install-foot.sh
set -e

# --- Paquete ---
if ! command -v foot &>/dev/null; then
    echo "-> Instalando foot..."
    sudo pacman -S --needed --noconfirm foot
else
    echo "-> foot ya esta instalado."
fi

# --- Configuracion ---
mkdir -p "$HOME/.config"
origen="$HOME/config_files/dotconfig/foot"
destino="$HOME/.config/foot"

if [ ! -d "$origen" ]; then
    echo "ERROR: no se encontro $origen (¿clonaste config_files?)"
    exit 1
fi

if [ -e "$destino" ] && [ ! -L "$destino" ]; then
    respaldo="${destino}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$destino" "$respaldo"
    echo "-> $destino ya existia; respaldado como $respaldo"
fi

ln -sfn "$origen" "$destino"
echo "-> Enlazado: $destino -> ~/config_files/dotconfig/foot"
echo "-> foot listo. Ejecutalo con: foot"
