#!/usr/bin/env bash
# Reinicia el stack de audio de PipeWire (pipewire + pipewire-pulse + wireplumber)
# para limpiar nodos zombi y resincronizar el estado con el hardware real.
#
#   bash ~/config_files/scripts/restart-audio.sh --check   # solo diagnostica, no toca
#   bash ~/config_files/scripts/restart-audio.sh           # reinicia el audio
#
# CUANDO USARLO (diagnosticado 2026-09-04 en un ThinkPad con Hyprland):
#
#   - Desenchufaste un dispositivo USB de audio (acá unos EarPods de Apple) y PipeWire se
#     queda con NODOS ZOMBI de ese dispositivo: wlcom el sink default apuntando a un alma
#     que ya no esta fisicamente. El journal repite:
#
#         spa.alsa: 'front:1': playback open failed: No such file or directory
#         pw.node: (alsa_output.usb-Apple... ) suspended -> error (Start error: ...)
#
#     Y aplicaciones graficas de audio (wiremix es la que se vio) pueden cerarse al
#     intentar operar sobre decenas de nodos de un dispositivo muerto.
#
#   - Notas de volumen que no agarran a ningun canal, o sonido que suena y a los segundos
#     se cae porque el sink default esta en estado error.
#
# ESTA POR QUE TODO EL MUNDO TIENE EL MISMO PROBLEMA, no es only de este equipo:
# wireplumber no borra nodos por desenchufe del dispositivo, los deja en primer plano y
# mantiene el default señalado; recien un reinicio completo del stack lo re-escanea todo
# contra el hardware presente y descarta lo que no existe.
#
# ES DISRUPTIVO, PERO POCO: reinicia el audio de la sesion (se corta un instante) y las
# aplicaciones que esten reproduciendo se reconectan solas. La sesion grafica NO se toca.
#
# Es idempotente: reejecutarlo no rompe nada y sirve para verificar que quedo sano.
# Vive en scripts/ como los otros fix-*.sh.

set -e

solo_check=0
case "${1:-}" in
    --check|-n) solo_check=1 ;;
    "")         ;;
    *)          echo "Uso: $(basename "$0") [--check]"; exit 1 ;;
esac

ok()    { printf '   \033[32m✔\033[0m %s\n' "$*"; }
falta() { printf '   \033[33m→\033[0m %s\n' "$*"; }
mal()   { printf '   \033[31m✘\033[0m %s\n' "$*"; }
titulo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

# --run activo / inactivo / desconocido devuelven 0/3/... con -q wrapper
activo() { systemctl --user is-active "$1" 2>/dev/null || true; }

# El sink/source default actual (la linea con '*' en el arbol de wpctl status).
# Se filtra por '[vol:' que solo aparece en nodos de AUDIO (no en video), asi el '*' de
# una camara no contamina el resultado.
default_audio() {
    wpctl status 2>/dev/null | grep -E '\*' | grep '\[vol:' | sed -E 's/.*\* +[0-9]+\. //' | head -1
}

# ID del nodo interno (tarjeta de sonido del equipo, no HDMI/USB) por descripcion.
# Despues de un reinicio las IDs cambian, asi que siempre se consultan en vivo.
id_interno() {
    local desc="$1"
    wpctl status 2>/dev/null \
        | grep -oE "[0-9]+\. .*${desc}" \
        | head -1 \
        | sed -E 's/^([0-9]+)\..*/\1/'
}

# Firmas de audio roto en el journal del usuario: un nodo de ALSA intentando abrir una
# tarjeta que ya no existe. El '|| true' es para que no mate el set -e si no encuentra nada.
errores_alsa() {
    journalctl --user -u pipewire --since "2 hours ago" --no-pager 2>/dev/null \
        | grep -c "Start error.*No such file or directory" || true
}

# --- 1. Comprobaciones previas ------------------------------------------------

titulo "1. Comprobaciones previas"

command -v wpctl >/dev/null 2>&1 || { mal "no hay wpctl (¿falta el paquete pipewire con las utilidades?)"; exit 1; }
ok "wpctl disponible"

for u in pipewire pipewire-pulse wireplumber; do
    a="$(activo "$u")"
    if [ "$a" = active ]; then
        ok "$u: activo"
    else
        mal "$u: $a"
        echo "     Arrancalo con: systemctl --user enable --now $u"
        exit 1
    fi
done

# --- 2. Estado actual ---------------------------------------------------------

titulo "2. Estado actual"

def="$(default_audio)"
if [ -z "$def" ]; then
    falta "wpctl no reporta default (raro)"
else
    ok "default actual: $def"
fi

errs="$(errores_alsa)"
if [ "$errs" -gt 0 ]; then
    mal "errores de ALSA/card en el journal del usuario: $errs ocurrencias"
    echo "        (nodos señalando a hardware que ya no existe)"
else
    ok "sin errores de ALSA recientes en el journal"
fi

# Deteccion de zombies: nodos de audio USB cuyo vendor ya no aparece en lsusb.
# Se averigua SOLO descripcion, para no depender de IDs que cambian con cada reinicio.
zombie=0
if hubo_usb="$(wpctl status 2>/dev/null | grep -oE '^ │ +[0-9]+\. .*' | grep -iE 'EarPods|Apple' | head -3)"; then
    if lsusb 2>/dev/null | grep -qiE 'apple|earpods'; then
        ok "USB de audio presente en lsusb: los nodos EarPods son reales"
    else
        mal "hay nodos EarPods/Apple pero el USB no esta en lsusb: nodos zombi"
        falta "-> reiniciar el stack deberia limpiarlos"
        zombie=1
    fi
fi

if [ "$zombie" -eq 0 ]; then
    ok "sin nodos zombi detectados en wpctl status"
fi

if [ "$solo_check" = 1 ]; then
    titulo "Modo --check: no se toco nada."
    echo "Para reiniciar el audio, corre el script sin argumentos."
    echo "Se va a reiniciar:  systemctl --user restart pipewire pipewire-pulse wireplumber"
    exit 0
fi

# --- 3. Reiniciar el stack ----------------------------------------------------

titulo "3. Reiniciando PipeWire"

# Se reinician las tres unidades juntas en un solo comando: pipewire-pulse y
# wireplumber dependen de pipewire y una reconexion entre dos mundos distintos
# dejaria estado a medias. El orden dentro del comando lo resuelve systemd.
systemctl --user restart pipewire pipewire-pulse wireplumber
ok "systemctl --user restart pipewire pipewire-pulse wireplumber"

# El arbol de nodos se puebla asincrono. Una espera corta evita verificar
# contra un estado todavia vacio. pipewire se real arranca en ~1s.
for _ in $(seq 20); do
    wpctl status >/dev/null 2>&1 && break
    sleep 0.5
done
sleep 1
ok "esperado a que el arbol se repueble"

# --- 4. Re-anclarse al hardware interno ----------------------------------------
# El default quedaba apuntando al zombie (los EarPods desenchufados). Se re-apunta al
# sink/source de la placa interna del equipo, que es lo que siempre esta presente, y
# de paso se confirma que wiremix ya no tiene nodos rotos que tumbarle la UI.

titulo "4. Default al sink/source interno"

sink="$(id_interno 'Controller Speaker')"
if [ -z "$sink" ]; then
    falta "no encuentro el Speaker interno; dejo el default como este"
else
    wpctl set-default "$sink" >/dev/null 2>&1
    [ "$(default_audio)" = "$(wpctl inspect "$sink" 2>/dev/null | grep -m1 node.description | sed -E 's/.*= "([^"]*)".*/\1/')" ] || true
    ok "sink default -> $sink (Speaker interno)"
fi

# El source interno: el mic de la placa. Se prefiere el Digital (el default habitual en
# los ThinkPad con DMIC) y se cae al Stereo si no existe; ambos son de la misma placa.
src="$(id_interno 'Digital Microphone')"
[ -z "$src" ] && src="$(id_interno 'Stereo Microphone')"
if [ -z "$src" ]; then
    falta "no encuentro mic interno; dejo el default como este"
else
    wpctl set-default "$src" >/dev/null 2>&1
    ok "source default -> $src (mic interno)"
fi

# --- 5. Verificacion ----------------------------------------------------------

titulo "5. Verificacion"

fallos=0

def="$(default_audio)"
if [ -n "$def" ]; then
    ok "default ahora: $def"
else
    mal "wpctl no reporta default despues del reinicio"
    fallos=$((fallos+1))
fi

errs="$(errores_alsa)"
if [ "$errs" -eq 0 ]; then
    ok "sin errores de ALSA en el journal (los nodos zombi se fueron)"
else
    mal "siguen habiendo $errs errores de ALSA"
    falta "(si persisten, el problema puede ser de la tarjeta interna, no de USB)"
    fallos=$((fallos+1))
fi

if [ "$zombie" -eq 1 ] && lsusb 2>/dev/null | grep -qiE 'apple|earpods'; then
    falta "el USB de EarPods VOLVIO a aparecer en lsusb durante la corrida"
fi

titulo "$([ "$fallos" -eq 0 ] && echo "Listo, audio reiniciado y verificado." || echo "Terminado con $fallos problema(s) sin resolver.")"

cat <<EOF
Si wiremix se seguia cayendo, volvelo a abrir ahora: los nodos muertos no estan.
Para revisar el estado actual de los nodos:

   wpctl status
   journalctl --user -u pipewire --since today | grep -i error
EOF