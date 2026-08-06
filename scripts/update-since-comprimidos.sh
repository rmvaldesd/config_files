#!/usr/bin/env bash
# Pone al día un equipo que se instaló ANTES de la tanda del módulo de swap, el
# arreglo del tooltip de rclone-sync y los archivos comprimidos en Thunar.
#
# De esa tanda, lo ÚNICO que necesita instalar algo son los comprimidos: el
# módulo de swap y el arreglo de rclone viajan dentro de archivos que ya llegan
# por 'git pull' a través de los symlinks de dotconfig/. Pero llegar no alcanza
# -- hay tres procesos vivos que siguen corriendo con la versión vieja en
# memoria, y este script los sacude:
#
#   thunar       -> se queda en segundo plano aunque cierres todas las ventanas,
#                   y los plugins se cargan UNA vez, al arrancar. Sin reiniciarlo
#                   el menú del clic derecho no muestra "Extraer aquí" por más
#                   que el plugin esté instalado.
#   waybar       -> hay que avisarle que releyó su config, si no el módulo de
#                   swap no aparece hasta el próximo login.
#   rclone-sync  -> el demonio es un script de bash, y bash lee el archivo A
#                   MEDIDA que lo ejecuta: el 'git pull' le cambió el archivo
#                   abajo de los pies. Reiniciarlo no es sólo para que tome el
#                   código nuevo, es para que no se rompa a la mitad.
#
# Síntomas de que un equipo necesita esto:
#   - El clic derecho en Thunar sobre un .zip o .rar no ofrece extraer.
#   - La barra no muestra el porcentaje de swap entre CPU y memoria.
#   - El tooltip de la nube de sincronización aparece vacío (o con el texto del
#     módulo de al lado): es el bug del '<->' que rompía el parseo de pango.
#
# Uso:
#   bash ~/config_files/scripts/update-since-comprimidos.sh
#
# Es idempotente: reejecutarlo en un equipo ya al día no cambia nada, y ni
# siquiera pide sudo si no falta ningún paquete.

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
# 2. COMPRIMIDOS EN EL MENÚ DE THUNAR
# ==========================================
# Tres capas: el plugin pone las opciones en el menú, xarchiver las ejecuta, y
# unrar/7zip/zip son los que realmente abren cada formato. Ver la sección
# "Archivos comprimidos" de docs/hyprland/README.md.
paquetes_comprimidos=(
    thunar-archive-plugin
    xarchiver
    unrar
    7zip
    zip
)

# Se calcula lo que falta ANTES de llamar a pacman, en vez de tirarle la lista
# entera con --needed. Con --needed pacman igual no reinstala nada, pero sudo
# pide la clave igual: el script te interrumpiría para no hacer nada. Así, en un
# equipo ya al día, esto termina en silencio.
faltantes=()
for p in "${paquetes_comprimidos[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || faltantes+=("$p")
done

if [ ${#faltantes[@]} -eq 0 ]; then
    echo "-> Comprimidos: ya están los ${#paquetes_comprimidos[@]} paquetes, no hay nada que instalar."
else
    echo "-> Instalando paquetes para comprimidos: ${faltantes[*]}"
    sudo pacman -S --needed --noconfirm "${faltantes[@]}"
fi

# Thunar carga los plugins al arrancar y se queda de demonio en segundo plano
# aunque cierres todas las ventanas: sin este 'thunar -q' el menú nuevo no
# aparece hasta el próximo login. La siguiente vez que abras una carpeta,
# Thunar arranca solo. Si no está corriendo, no hay nada que reiniciar.
if pgrep -x thunar >/dev/null 2>&1; then
    echo "-> Reiniciando Thunar para que cargue el plugin del menú..."
    thunar -q || true
fi

# ==========================================
# 3. MÓDULO DE SWAP EN LA BARRA
# ==========================================
# El script del módulo ya llegó con el pull (dotconfig/waybar está enlazado a
# ~/.config/waybar), pero waybar tiene su config en memoria. SIGUSR2 es "releé
# la config" -- no reinicia el proceso, así que la barra no parpadea.
#
# No alcanza con confiar en auto-reload.sh: su inotifywait vigila el DIRECTORIO
# ~/.config/waybar y no es recursivo, así que un pull que sólo toque
# scripts/swap.sh no dispara nada.
if pgrep -x waybar >/dev/null 2>&1; then
    echo "-> Recargando waybar para que aparezca el módulo de swap..."
    killall -SIGUSR2 waybar || true
else
    echo "-> waybar no está corriendo; el módulo de swap aparecerá al iniciarla."
fi

# ==========================================
# 4. DEMONIO DE SINCRONIZACIÓN CON DRIVE
# ==========================================
# Sólo si este equipo tiene la sincronización instalada: el módulo de waybar
# existe en todos (el config está versionado), pero el servicio no.
if systemctl --user list-unit-files rclone-sync.service >/dev/null 2>&1 &&
   systemctl --user is-active --quiet rclone-sync.service; then
    echo "-> Reiniciando rclone-sync para que tome el código nuevo..."
    systemctl --user restart rclone-sync.service
elif systemctl --user list-unit-files rclone-sync.service >/dev/null 2>&1; then
    echo "-> rclone-sync está instalado pero no corriendo; no hay nada que reiniciar."
else
    echo "-> Este equipo no tiene la sincronización con Drive instalada; se omite."
fi

echo "---"
echo "=== Equipo actualizado ==="
echo "Comprimidos: clic derecho sobre un .zip/.rar/.7z en Thunar -> 'Extraer aquí'."
echo "             Crear .rar NO se puede (necesita el binario propietario 'rar',"
echo "             que está en AUR); para comprimir usá zip o 7z."
echo "Barra:       el porcentaje de swap va entre CPU y memoria; el tooltip dice si"
echo "             abajo hay zram, zswap, partición o archivo."
echo "Sincro:      el tooltip de la nube ya no sale vacío (era el '<->' rompiendo"
echo "             el parseo de pango) y ahora está en inglés."

exit 0
