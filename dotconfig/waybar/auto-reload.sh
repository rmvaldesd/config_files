#!/bin/sh
# Lanza waybar, la vigila y la recarga cuando cambia su config.
#
# Hace DOS cosas que antes estaban separadas:
#
#   1) HOT RELOAD: inotify on ~/.config/waybar; on a change it RESTARTS waybar (kills
#      it and the supervisor below brings it back).
#
#      NOTE: it used to send SIGUSR2 ("re-read the config") without restarting. On
#      waybar 0.15.0 that path crashes: reloading trips a GLib-GIO assertion
#      (g_application_impl_command_line: object_id != 0) and aborts with SIGABRT
#      (upstream: Waybar #3546). A restart costs a bar flicker, but it holds.
#   2) SUPERVISIÓN: si waybar MUERE, la vuelve a levantar hasta 3 veces por sesión.
#      A la cuarta caída se rinde y notifica.
#
# IMPORTANTE: este script AHORA LANZA waybar. Antes hyprland.lua la lanzaba por su
# cuenta ('hl.exec_cmd("waybar")') y este script sólo la recargaba. Ese exec_cmd se
# eliminó al agregar la supervisión: si los dos la lanzaran tendrías DOS barras
# superpuestas, y la que supervisa este script no sería la que ves.

# Cuántas veces se reintenta antes de rendirse. El contador es POR SESIÓN y NO se
# resetea: tres caídas espaciadas a lo largo de días gastan el presupuesto igual que
# tres seguidas. Es a propósito -- el objetivo es que una barra que falla de verdad
# termine avisando en vez de reciclarse para siempre en silencio.
MAX_REINTENTOS=3
reintentos=0

# Waybar pid + reload flag. The watcher runs in a subshell, so it cannot touch the
# parent's variables; the flag file is how it tells the supervisor "this death was a
# deliberate restart, do not spend a retry".
run_dir="${XDG_RUNTIME_DIR:-/tmp}"
waybar_pid_file="$run_dir/waybar.pid"
reload_flag="$run_dir/waybar-reload.flag"
rm -f "$reload_flag"

# Cuántos segundos tiene que aguantar waybar para considerarla "estable" y devolverle
# el presupuesto completo de reintentos.
#
# Sin esto el contador sería acumulativo de por vida: tres caídas sueltas repartidas a
# lo largo de una semana de uptime lo agotarían igual que tres seguidas, y la cuarta
# -- meses después, sin relación con las anteriores -- te dejaría sin barra. Lo que
# querés detectar es un CRASH-LOOP, no un total histórico.
#
# El contrapeso: una waybar que se cae cada 6 minutos para siempre nunca agota los
# reintentos y se relanza indefinidamente. Es a propósito. Ese caso no es un
# crash-loop, es una barra que anda mal de a ratos, y matarla del todo sería peor.
UMBRAL_ESTABLE=300    # 5 minutos

# --- Config generada ----------------------------------------------------
# Waybar lee JSON y no puede leer ~/.local_host_settings, así que su alto no puede
# vivir ahí de forma directa. render_config() toma el template versionado
# (config.jsonc del repo, que por el symlink es ~/.config/waybar/config.jsonc) y le
# inyecta WAYBAR_HEIGHT de settings. La salida va a ~/.cache (FUERA del directorio
# vigilado) para que el propio render no dispare el inotifywatch de abajo y entre en
# un loop consigo mismo.
config_template="$HOME/.config/waybar/config.jsonc"
config_salida="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/config.jsonc"

render_config() {
  local height
  height=$(awk -F= '$1=="WAYBAR_HEIGHT" {print $2}' "$HOME/.local_host_settings" 2>/dev/null)
  case "$height" in
    ''|*[!0-9]*) height=34 ;;   # multineumónico del default del template
  esac
  mkdir -p "$(dirname "$config_salida")" || return 1
  sed "s/^\([[:space:]]*\)\"height\": *[0-9][0-9]*\(,*\)[[:space:]]*$/\1\"height\": $height\2/" \
    "$config_template" > "$config_salida" || return 1
}

# Marca que la salida es intencional (fin de sesión), no una caída. Sin esto, el
# 'wait' de abajo retorna cuando Hyprland mata a waybar al cerrar sesión y el script
# la relanzaría en pleno logout.
terminando=0

# --- 1. Recarga en caliente, en segundo plano ---------------------------------
# Va en background porque el loop principal necesita el primer plano para hacer
# 'wait' sobre waybar. Los dos loops son independientes y ninguno puede bloquear
# al otro.
#
# El inotifywait se lanza con '&' y se espera con 'wait' en vez de invocarlo directo
# en la condición del while. Parece un rodeo, pero es lo que permite MATARLO: si el
# while lo invocara en primer plano, un 'kill' al watcher se llevaría sólo al subshell
# y dejaría al inotifywait HUÉRFANO, vigilando el directorio para una waybar que ya no
# existe. Verificado: sin esto el proceso sobrevive al supervisor. Teniendo el PID del
# hijo, el trap de acá abajo lo baja de verdad.
vigilar_config() {
    trap 'kill "$hijo" 2>/dev/null; exit 0' TERM INT HUP
    while :; do
        inotifywait -e close_write "$HOME/.config/waybar" &
        hijo=$!
        # El '|| break' corta el loop si inotifywait falla de verdad (el directorio
        # desapareció); si no, un error permanente giraría en vacío para siempre.
        wait "$hijo" || break
        render_config
        # Restart waybar instead of sending SIGUSR2 (which crashes on this version).
        # The flag is written BEFORE the signal so the supervisor never sees the death
        # before it knows the restart was deliberate.
        : > "$reload_flag"
        pid=$(cat "$waybar_pid_file" 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2> /dev/null || rm -f "$reload_flag"
        else
            rm -f "$reload_flag"
        fi
    done
}
vigilar_config &
watcher=$!

# Al terminar, llevarse puestos al watcher (y con él su inotifywait) Y a waybar.
#
# Matar a waybar acá no es redundante aunque en un logout normal Hyprland ya mate a
# todos sus hijos. Importa cuando se mata SÓLO a este script: sin esta parte waybar
# queda huérfana y viva, y el siguiente arranque de auto-reload.sh levantaría una
# SEGUNDA barra encima. Verificado: sin el '$waybar_pid' en el trap, la waybar
# sobrevive al supervisor.
#
# $waybar_pid se expande cuando el trap DISPARA, no cuando se define, así que ya
# tiene el PID vigente. Si aún no hay ninguno queda vacío y el kill falla en silencio.
trap 'terminando=1; kill "$watcher" $waybar_pid 2>/dev/null; rm -f "$waybar_pid_file" "$reload_flag"' TERM INT HUP

# --- 2. Supervisión -----------------------------------------------------------
while :; do
    arranque=$(date +%s)
    # Se arranca SIEMPRE desde la config generada: si el render falla (template
    # ausente) cae a la config del repo, que es la que está versionada.
    if render_config; then
        waybar -c "$config_salida" &
    else
        waybar &
    fi
    waybar_pid=$!
    printf '%s\n' "$waybar_pid" > "$waybar_pid_file"

    # Bloquea hasta que waybar termine, por la razón que sea. Como este script es su
    # padre, 'wait' es la forma exacta de enterarse: no hay polling ni ventana ciega.
    wait "$waybar_pid"
    codigo=$?

    # Salida intencional (logout): no cuenta como caída y no se relanza.
    [ "$terminando" -eq 1 ] && exit 0

    # Hot reload (the config changed): relaunch immediately without spending a retry.
    if [ -e "$reload_flag" ]; then
        rm -f "$reload_flag"
        continue
    fi

    # Si aguantó lo suficiente, la caída no es parte de un crash-loop: se le devuelve
    # el presupuesto entero.
    #
    # Este bloque va ANTES del chequeo de reintentos agotados, y ese orden es lo que
    # hace que la instancia estable "perdone" las caídas viejas: si fuera después,
    # una waybar que estuvo arriba horas se rendiría igual por tres caídas de la
    # semana pasada, que es justo lo que se quería evitar.
    vivio=$(( $(date +%s) - arranque ))
    if [ "$vivio" -ge "$UMBRAL_ESTABLE" ] && [ "$reintentos" -gt 0 ]; then
        echo "waybar aguantó ${vivio}s (>= ${UMBRAL_ESTABLE}s): contador reseteado" >&2
        reintentos=0
    fi

    # ¿Se acabaron los reintentos? Ojo con el orden: esto se evalúa ANTES de
    # incrementar, así que con MAX=3 el reparto es 3 relanzamientos y rendirse en la
    # CUARTA caída, que es lo pedido.
    if [ "$reintentos" -ge "$MAX_REINTENTOS" ]; then
        notify-send -u critical "Waybar" \
            "Se cayó $((reintentos + 1)) veces (último código: $codigo). Me rindo.\nCorré 'waybar' en una terminal para ver el error."
        echo "waybar murió $((reintentos + 1)) veces; se agotaron los reintentos" >&2
        kill "$watcher" 2>/dev/null
        exit 1
    fi

    reintentos=$((reintentos + 1))
    echo "waybar murió tras ${vivio}s (código $codigo); reintento $reintentos/$MAX_REINTENTOS" >&2

    # Sin esta pausa, una waybar que muere al instante -- config rota, binario
    # ausente -- quemaría los 3 reintentos en milisegundos, antes de que llegues a
    # ver la barra parpadear. Con la pausa la secuencia dura ~6s y el síntoma es
    # visible.
    sleep 2
done
