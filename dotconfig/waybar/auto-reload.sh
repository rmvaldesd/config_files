#!/bin/sh
# Lanza waybar, la vigila y la recarga cuando cambia su config.
#
# Hace DOS cosas que antes estaban separadas:
#
#   1) RECARGA EN CALIENTE: inotify sobre ~/.config/waybar; ante un cambio manda
#      SIGUSR2, que waybar interpreta como "relee la config". No reinicia el proceso.
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
        killall -SIGUSR2 waybar
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
trap 'terminando=1; kill "$watcher" $waybar_pid 2>/dev/null' TERM INT HUP

# --- 2. Supervisión -----------------------------------------------------------
while :; do
    arranque=$(date +%s)
    waybar &
    waybar_pid=$!

    # Bloquea hasta que waybar termine, por la razón que sea. Como este script es su
    # padre, 'wait' es la forma exacta de enterarse: no hay polling ni ventana ciega.
    wait "$waybar_pid"
    codigo=$?

    # Salida intencional (logout): no cuenta como caída y no se relanza.
    [ "$terminando" -eq 1 ] && exit 0

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
