#!/usr/bin/env bash
# Habilita los perfiles de bloqueo de pantalla (hypridle) en una máquina que YA tiene
# config_files clonado e instalado.
#
#   bash ~/config_files/scripts/enable-lock-profiles.sh            # deja office (5 min)
#   bash ~/config_files/scripts/enable-lock-profiles.sh home       # deja home  (10 min)
#
# Existe porque el symlink del perfil activo lo crea archdesktopinstall.sh, y en un
# equipo ya instalado no tiene sentido correr el instalador entero para eso. Hace las
# tres cosas que faltan: enlazar el comando en el PATH, crear el perfil activo y
# relanzar hypridle para que relea la config.
#
# Es idempotente: reejecutarlo no rompe ni cambia una elección previa.
#
# Vive en scripts/ y no en bin_configs/ por la misma razón que link-bins.sh: su trabajo
# es CREAR la entrada en el PATH, así que no puede depender de estar ya en el PATH.

set -e

perfil="${1:-office}"

repo="$HOME/config_files"
dir_perfiles="$repo/dotconfig/hypr/profiles"
activo="$dir_perfiles/active.conf"
selector="$repo/bin_configs/hypridle-profile"

# --- 1. Comprobaciones previas ------------------------------------------------
# Se hacen todas ANTES de tocar nada. Un fallo a mitad de camino dejaría la máquina
# en un estado peor que el inicial: con el symlink creado pero sin el comando para
# cambiarlo, por ejemplo.

[ -d "$dir_perfiles" ] || {
    echo "ERROR: no existe $dir_perfiles"
    echo "       Este equipo tiene una version de config_files anterior a los perfiles."
    echo "       Actualizala con: git -C $repo pull"
    exit 1
}

[ -f "$dir_perfiles/$perfil.conf" ] || {
    echo "ERROR: no existe el perfil '$perfil'."
    echo "Disponibles:"
    for f in "$dir_perfiles"/*.conf; do
        [ -f "$f" ] && [ ! -L "$f" ] && echo "  $(basename "$f" .conf)"
    done
    exit 1
}

# ~/.config/hypr tiene que apuntar al repo. Si no, hypridle leería OTRA config y este
# script parecería andar sin tener ningún efecto -- el peor tipo de fallo.
# Los DOS lados se resuelven con 'readlink -f'. Comparar el izquierdo resuelto contra
# el derecho crudo parece equivalente, pero falla si config_files vive bajo una ruta
# con symlinks: el enlace resuelve a la ruta real y la cadena literal no, así que una
# instalación perfectamente válida se rechazaría. Detectado probando con un $HOME
# falso en el que config_files era un symlink.
destino_hypr="$HOME/.config/hypr"
if [ ! -L "$destino_hypr" ] || [ "$(readlink -f "$destino_hypr")" != "$(readlink -f "$repo/dotconfig/hypr")" ]; then
    echo "ERROR: ~/.config/hypr no apunta a $repo/dotconfig/hypr"
    echo "       hypridle estaria leyendo otra config y esto no tendria efecto."
    echo "       Enlazalo con la seccion 9 de archdesktopinstall.sh."
    exit 1
fi

# La config tiene que ser la que sourcea el perfil. Si es una version vieja, los
# timeouts están escritos a mano y cambiar el symlink no haría absolutamente nada.
if ! grep -q "profiles/active.conf" "$destino_hypr/hypridle.conf"; then
    echo "ERROR: hypridle.conf no sourcea profiles/active.conf."
    echo "       Es una version anterior a los perfiles. Actualiza con: git -C $repo pull"
    exit 1
fi

command -v hypridle >/dev/null || {
    echo "ERROR: hypridle no esta instalado. Instalalo con: sudo pacman -S hypridle"
    exit 1
}

# --- 2. Enlazar el selector en el PATH ----------------------------------------
# Sólo si falta o apunta a otro lado, para no pedir sudo al pedo en cada reejecución.
# Igual que el guard de arriba: los dos lados resueltos. Comparar contra "$selector"
# crudo haría que en un repo bajo symlinks la condición diera siempre verdadera y el
# script pidiera sudo en cada ejecución aunque el enlace ya estuviera bien.
if [ "$(readlink -f /usr/local/bin/hypridle-profile 2>/dev/null)" != "$(readlink -f "$selector")" ]; then
    echo "-> Enlazando hypridle-profile en /usr/local/bin (requiere sudo)..."
    sudo ln -sfn "$selector" /usr/local/bin/hypridle-profile
else
    echo "-> hypridle-profile ya esta en el PATH."
fi

# El bit +x se pierde al clonar en algunos filesystems y sin él el symlink queda
# apuntando a algo que no corre.
[ -x "$selector" ] || chmod +x "$selector"

# --- 3. Aplicar el perfil -----------------------------------------------------
# Con Hyprland corriendo se delega en el selector, que ademas de mover el symlink
# relanza hypridle y VERIFICA que haya quedado vivo. Sin sesion grafica (SSH, TTY,
# durante una instalacion) no hay a quien relanzar, asi que se crea el symlink a mano
# y los tiempos nuevos entran solos en el proximo inicio de sesion.
if hyprctl version >/dev/null 2>&1; then
    echo "-> Aplicando perfil '$perfil' y relanzando hypridle..."
    "$selector" "$perfil"
else
    ln -sfn "$perfil.conf" "$activo"
    echo "-> Perfil '$perfil' activado."
    echo "   Hyprland no esta corriendo: los tiempos nuevos entran al iniciar sesion."
fi

echo
echo "Listo. Consulta o cambia el perfil con:"
echo "   hypridle-profile           # muestra el activo"
echo "   hypridle-profile home      # bloqueo a los 10 min"
echo "   hypridle-profile office    # bloqueo a los 5 min"
echo
# 'rehash' sólo hace falta en las terminales que ya estaban abiertas: zsh cachea el
# contenido de los directorios del PATH y no ve el comando recién enlazado hasta
# entonces. El síntoma (command not found sobre algo que sí existe) despista.
echo "Si una terminal ya abierta no encuentra el comando, ejecuta: rehash"
