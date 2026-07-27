#!/usr/bin/env bash
# Enlaza los ejecutables de config_files/bin_configs en /usr/local/bin.
#
# Lo invoca la sección 9 de archdesktopinstall.sh, pero también sirve suelto: cada vez
# que se suma un script nuevo a bin_configs/ hay que crearle el symlink, y en una
# máquina ya instalada correr esto es más rápido (y menos propenso a olvidos) que
# acordarse del 'ln -sfn' a mano:
#
#   bash ~/config_files/scripts/link-bins.sh
#
# Es idempotente: reejecutarlo sólo repone lo que falte.
# Vive en scripts/ y no en bin_configs/ a propósito: su trabajo es CREAR el PATH, así
# que no puede depender de estar ya en el PATH.

set -e

origen="$HOME/config_files/bin_configs"
destino="/usr/local/bin"

# power-profile-sync se EXCLUYE a propósito. No va como symlink sino COPIADO por la
# sección 10 del instalador: udev lee sus reglas antes de que se monte /home (acá un
# subvolumen btrfs), así que un symlink a ~/config_files estaría roto justo en ese
# momento y la regla no se dispararía nunca. Enlazarlo desde acá PISARÍA esa copia
# buena con un symlink roto para udev.
excluidos=(power-profile-sync)

[ -d "$origen" ] || { echo "ERROR: no existe $origen"; exit 1; }

echo "-> Enlazando ejecutables de bin_configs en $destino..."

enlazados=0
for ruta in "$origen"/*; do
    [ -f "$ruta" ] || continue
    nombre=$(basename "$ruta")

    # Sólo lo ejecutable: un archivo sin el bit +x en bin_configs/ es un descuido,
    # y enlazarlo dejaría un comando en el PATH que no corre.
    if [ ! -x "$ruta" ]; then
        echo "   OMITIDO (sin permiso de ejecución): $nombre"
        continue
    fi

    saltear=0
    for e in "${excluidos[@]}"; do
        [ "$nombre" = "$e" ] && saltear=1
    done
    if [ "$saltear" -eq 1 ]; then
        echo "   OMITIDO (se instala copiado, no enlazado): $nombre"
        continue
    fi

    sudo ln -sfn "$ruta" "$destino/$nombre"
    echo "   $destino/$nombre -> $ruta"
    enlazados=$((enlazados + 1))
done

echo "-> Listo: $enlazados enlace(s)."

# zsh cachea el contenido de los directorios del PATH: un comando recién enlazado no
# aparece en las terminales YA abiertas hasta hacer 'rehash'. Se avisa porque el
# síntoma (command not found sobre algo que sí existe) despista.
echo "   Si una terminal abierta no encuentra un comando nuevo, ejecutá: rehash"
