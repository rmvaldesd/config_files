#!/usr/bin/env bash
# Enlaza los .desktop de config_files/applications en ~/.local/share/applications.
#
# Lo invocan las secciones de archdesktopinstall.sh que enlazan teams-for-linux y glow,
# pero también sirve suelto: cada vez que se agrega un .desktop nuevo a applications/
# (o se cambia uno existente) hay que refrescar el enlace, y correr esto es más rápido
# (y menos propenso a olvidos) que acordarse del 'ln -sfn' a mano:
#
#   bash ~/config_files/scripts/link-applications.sh
#
# Es idempotente: reejecutarlo sólo repone lo que falte. Reconoce un .desktop suelto
# (creado por la app o por un paquete) en el destino y lo respalda, igual que hace el
# instalador con teams-for-linux.
#
# applications/ del repo mapea a ~/.local/share/applications, que tiene prioridad sobre
# /usr/share/applications cuando el archivo se llama igual. Así un override (como el de
# teams-for-linux) sobrevive a los upgrades del paquete, que reescriben el de /usr/share.

set -e

origen="$HOME/config_files/applications"
destino="$HOME/.local/share/applications"

[ -d "$origen" ] || { echo "ERROR: no existe $origen"; exit 1; }

mkdir -p "$destino"

echo "-> Enlazando .desktop de applications/ en $destino..."

enlazados=0
for ruta in "$origen"/*.desktop; do
    [ -f "$ruta" ] || continue
    nombre=$(basename "$ruta")

    if [ -e "$destino/$nombre" ] && [ ! -L "$destino/$nombre" ]; then
        respaldo="$destino/$nombre.bak.$(date +%Y%m%d%H%M%S)"
        mv "$destino/$nombre" "$respaldo"
        echo "   $nombre: existía suelto; respaldado como $(basename "$respaldo")"
    fi

    ln -sfn "$ruta" "$destino/$nombre"
    echo "   $destino/$nombre -> $ruta"
    enlazados=$((enlazados + 1))
done

# Refresca mimeinfo.cache para que xdg-open sepa qué app abre MimeType nuevos y los
# handlers de esquema. Sin esto el .desktop igual sirve para el lanzador (rofi drun).
if command -v update-desktop-database > /dev/null; then
    update-desktop-database "$destino"
fi

echo "-> Listo: $enlazados enlace(s)."