#!/bin/bash
#
# Módulo custom/language de waybar: qué distribución de teclado está activa.
#
# En la barra: "LA" o "ES" y NADA MÁS -- es el único módulo sin icono, y es a propósito.
# Los dos layouts son el MISMO idioma (español de Latinoamérica y de España), así que
# ningún glifo los distingue: un teclado o un globo serían idénticos para los dos y se
# perdería justo lo que el módulo existe para decir. Las banderas, que es la convención
# habitual, tampoco sirven acá por dos motivos independientes: no hay ninguna fuente
# emoji instalada -- se probó y salen los cuadraditos con el codepoint -- y "latam" es
# una REGIÓN sin bandera, así que habría que elegir un país arbitrario y etiquetarlo mal.
# Para un idioma, dos letras son el símbolo más claro que hay.
#
# En el tooltip: el nombre completo del layout, que es lo que esas dos letras no pueden
# decir. Sale de 'active_keymap' de Hyprland y NO está escrito acá: así dice el nombre
# real de xkb ("Spanish (Latin American)"), y si algún día se agrega un tercer layout el
# tooltip ya lo nombra bien sin tocar este archivo.

# Una sola llamada a hyprctl para las dos cosas: el índice, que decide la etiqueta corta,
# y el keymap, que arma el tooltip. Corre una vez por segundo ("interval": 1), así que no
# conviene pagar dos.
#
# El '2>/dev/null' y el '|| true' evitan que un hyprctl que falle -- o que devuelva JSON
# vacío durante un arranque -- mande un error por stderr una vez por segundo.
#
# El 'head -1' es defensivo: Hyprland reporta VARIOS teclados (video-bus, power-button,
# los botones extra del ThinkPad...) y cuál queda marcado como 'main' llegó a cambiar de
# un llamado a otro. Todos comparten layout porque el toggle es 'switchxkblayout all', así
# que cualquiera sirve; lo que no sirve es que salgan dos líneas y se rompa el parseo.
DATOS=$(hyprctl devices -j 2>/dev/null \
    | jq -r '.keyboards[] | select(.main == true) | "\(.active_layout_index)\t\(.active_keymap)"' 2>/dev/null \
    | head -1 || true)

INDICE=${DATOS%%$'\t'*}
KEYMAP=${DATOS#*$'\t'}

# OJO con el índice: 0 y 1 salen del ORDEN de 'kb_layout = "latam,es"' en hyprland.lua.
# Si algún día se reordena esa lista, las etiquetas de acá quedan mintiendo en silencio
# -- no falla nada, sólo dice la que no es. El tooltip no tiene ese problema porque no
# depende del orden, así que ante la duda vale más lo que diga el tooltip.
case "$INDICE" in
    0) ETIQUETA="LA" ;;
    1) ETIQUETA="ES" ;;
    # Si no se pudo leer, no se inventa: un texto vacío hace que waybar esconda el
    # módulo, que es preferible a mostrar un layout que quizá no es el activo.
    *) ETIQUETA="" ;;
esac

if [ -z "$ETIQUETA" ]; then
    printf '{"text":"","tooltip":""}\n'
    exit 0
fi

# xkb llama "Spanish" a secas al layout de España, porque es el que no lleva calificativo.
# Solo, es ambiguo -- justo al lado de "Spanish (Latin American)", que sí lo lleva --, así
# que se le agrega el país. Es lo ÚNICO que este script le retoca al nombre que da
# Hyprland, y se limita a esa cadena exacta: cualquier otro layout pasa tal cual, de modo
# que agregar un tercero al kb_layout no obliga a tocar nada de acá.
NOMBRE=${KEYMAP:-unknown}
[ "$NOMBRE" = "Spanish" ] && NOMBRE="Spanish (Spain)"

# 'grp:alt_shift_toggle' es lo que fija kb_options en hyprland.lua; el click lo hace el
# 'on-click' del módulo. Se nombran los dos porque el atajo es el que uno olvida.
TOOLTIP="Keyboard layout: $NOMBRE
Alt+Shift or click to switch"

# El JSON lo arma jq y no un printf a mano: el nombre del keymap viene de afuera y podría
# traer comillas o barras. jq ya es dependencia de este script, así que no cuesta nada.
#
# '-c' (compacto) NO es opcional: por defecto jq imprime el objeto en varias líneas, y
# waybar espera UNA línea de JSON por lectura.
jq -nc --arg t "$ETIQUETA" --arg tt "$TOOLTIP" '{text:$t, tooltip:$tt}'
