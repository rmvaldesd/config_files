#!/usr/bin/env bash
# Diagnostica si el stack de audio esta en un loop de errores y, solo con --fix,
# reinicia el audio de usuario. Se corre a mano cuando el audio se comporte raro
# (grabaciones que se cortan solas, nodos que entran y salen todo el tiempo).
#
#   ~/config_files/scripts/detect-audio-loop.sh         # solo diagnostica
#   ~/config_files/scripts/detect-audio-loop.sh --fix   # diagnostica y reinicia si hace falta
#
# Dos capas de loop, con su firma:
#
#   1. STACK DE AUDIO (pipewire/wireplumber). Los nodos (bluez, USB) caen una y otra
#      vez en rapida sucesion: 'pw.node: (...) running -> error (Received error event)'.
#      El loop es la RAFAGA: decenas de eventos en pocos segundos, no un evento suelto.
#      Se arregla reseteando el stack de usuario:
#        systemctl --user restart wireplumber pipewire pipewire-pulse
#
#   2. KERNEL / USB (p.ej. los EarPods USB-C). El kernel desenchufa/reconecta el
#      dispositivo a nivel USB: 'USB disconnect', 'Reset device', 'cannot submit
#      urb'. Ese loop NO lo cura el restart de pipewire: hay que desvincular/revincular
#      el device por sysfs (o desconectar y volver a enchufar el cable).
#
# Umbrales por defecto: si hay >= ERRORES en una ventana de VENTANA segundos, se
# considera loop. Ajustables con --window=N o --threshold=N.

set -euo pipefail

WINDOW="${WINDOW:-10}"        # segundos hacia atras que se miran
THRESHOLD="${THRESHOLD:-5}"   # minimo de eventos para hablar de loop
MAX_LINEAS="${MAX_LINEAS:-5}" # lineas de ejemplo por capa

boom=0
caso="${1:-}"
while [ "${1:-}" ]; do
    case "$1" in
        --fix)        boom=1 ;;
        --check|-n)   boom=0 ;;
        --window=*)   WINDOW="${1#--window=}" ;;
        --threshold=*) THRESHOLD="${1#--threshold=}" ;;
        -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Uso: $(basename "$0") [--fix] [--window=S] [--threshold=N]" >&2; exit 1 ;;
    esac
    shift
done

ok()    { printf '   \033[32m✔\033[0m %s\n' "$*"; }
aviso() { printf '   \033[33m→\033[0m %s\n' "$*"; }
mal()   { printf '   \033[31m✘\033[0m %s\n' "$*"; }
titulo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

# journalctl no soporta "10 seconds ago" en --since a la primera con algunas
# versiones segun locale; "-t "" --since=-10s" es la forma portable.
SINCE="-${WINDOW}s"

# ---- Capa 1: stack de audio (pipewire/wireplumber) --------------------------

n_audio=0
mapfile -t audio_lines < <(journalctl --user -u pipewire -u wireplumber \
    --since="$SINCE" --no-pager 2>/dev/null \
    | grep "error (Received error event)" || true)
n_audio=${#audio_lines[@]}

# ---- Capa 2: kernel / USB (disconnect, reset, urb) ---------------------------

n_usb=0
mapfile -t usb_lines < <(journalctl -k --since="$SINCE" --no-pager 2>/dev/null \
    | grep -E "USB disconnect|Reset device|cannot submit|urb.*status|reset_resume|device not accepting" || true)
n_usb=${#usb_lines[@]}

# ---- Verapresentar -----------------------------------------------------------

titulo "Audio loop check (ventana ${WINDOW}s, umbral ${THRESHOLD} eventos)"

if [ "$n_audio" -ge "$THRESHOLD" ]; then
    mal "stack de audio en loop: $n_audio eventos 'error (Received error event)' en ${WINDOW}s"
    printf '%s\n' "${audio_lines[@]:0:$MAX_LINEAS}" | sed 's/^/     /'
else
    ok "stack de audio tranquilo (${n_audio} eventos en ${WINDOW}s)"
fi

if [ "$n_usb" -ge "$THRESHOLD" ]; then
    mal "kernel/usb en loop: $n_usb eventos de disconnect/reset/urb en ${WINDOW}s"
    printf '%s\n' "${usb_lines[@]:0:$MAX_LINEAS}" | sed 's/^/     /'
else
    ok "kernel/usb tranquilo (${n_usb} eventos en ${WINDOW}s)"
fi

# EarPods USB-C (Apple 05ac:110b): si estan conectados ahora, se avisa el bus
# por si el loop es de ellos y hay que desvincular/revincular por sysfs.
bus=""
if lsusb 2>/dev/null | grep -q "05ac:110b"; then
    bus=$(journalctl -k --since="$SINCE" --no-pager 2>/dev/null \
        | grep -oE "usb [0-9]+-[0-9]+(?=:)" | tail -1 || true)
    [ -n "$bus" ] && aviso "EarPods USB-C detectados en $bus"
fi

en_loop=0
[ "$n_audio" -ge "$THRESHOLD" ] && en_loop=1
[ "$n_usb"   -ge "$THRESHOLD" ] && en_loop=1

if [ "$en_loop" = 0 ]; then
    titulo "Sin loop: el audio esta bien."
    exit 0
fi

if [ "$boom" = 0 ]; then
    titulo "Loop detectado. Para reiniciar el audio: $(basename "$0") --fix"
    exit 1
fi

# ---- --fix: reiniciar el stack de audio (solo capa user) ---------------------

titulo "Reiniciando el stack de audio de usuario..."

units=()
for u in wireplumber pipewire pipewire-pulse pipewire-media-session; do
    systemctl --user list-unit-files "$u.service" --no-legend 2>/dev/null | grep -q . && units+=("$u")
done
if [ "${#units[@]}" -gt 0 ]; then
    systemctl --user restart "${units[@]}"
    ok "reiniciados: ${units[*]}"
else
    mal "no hay unidades de audio de usuario; nada que reiniciar"
fi

sleep 2

n_audio2=0
mapfile -t audio_lines2 < <(journalctl --user -u pipewire -u wireplumber \
    --since="$SINCE" --no-pager 2>/dev/null | grep "error (Received error event)" || true)
n_audio2=${#audio_lines2[@]}

if [ "$n_audio2" -ge "$THRESHOLD" ]; then
    mal "hubo loop trayendo audio errores: sigue con $n_audio2 eventos tras el restart"
else
    ok "tras el restart hay $n_audio2 eventos de error -> stack de audio sano"
fi

if [ "$n_usb" -ge "$THRESHOLD" ]; then
    mal "la capa KERNEL siguió en loop; el restart de pipewire no la cura. Desconecta el cable USB del device y vuelve a enchufarlo, o desvincúlalo:"
    echo "       echo \"$bus\" | sudo tee /sys/bus/usb/drivers/usb/unbind && sleep 2 && echo \"$bus\" | sudo tee /sys/bus/usb/drivers/usb/bind" | sed 's/^/     /'
    exit 1
fi

titulo "Listo, audio reiniciado."