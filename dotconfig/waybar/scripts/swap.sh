#!/usr/bin/env bash
#
# Módulo custom/swap de waybar.
#
# En la barra: el porcentaje de swap ocupado, y nada más -- un número al lado del de
# memoria. En el tooltip: QUÉ es ese swap, que es la parte que ningún módulo estándar
# de waybar cuenta y la razón de que este script exista. "70% de swap" significa cosas
# muy distintas según lo que haya debajo:
#
#   zram      -> un disco comprimido EN RAM. Los GiB que anuncia son virtuales: 4 GiB de
#                zram llenos pueden estar ocupando 900 MiB reales de RAM. Que se llene no
#                implica tocar el disco ni que el equipo vaya a arrastrarse.
#   partición -> swap de verdad en el disco. Llenarla sí duele.
#   archivo   -> igual que la partición, pero sobre el filesystem.
#   zswap     -> NO es un swap: es una caché comprimida en RAM que se pone DELANTE del
#                swap real, así que no aparece en /proc/swaps ni suma tamaño. Por eso se
#                informa como una línea aparte y no como un dispositivo.
#
# El equipo puede tener varios a la vez (esa es justamente la gracia de las prioridades),
# así que el tooltip los lista todos y el porcentaje de la barra es el agregado.
#
# Todo sale de /proc y /sys: sin zramctl, sin root y sin depender de que util-linux traiga
# tal o cual versión. Los contadores de zswap sí viven en debugfs y son sólo para root, de
# modo que de zswap se informa la configuración (activo, compresor) y no su ocupación.
#
# El texto que se ve (barra y tooltip) va en inglés, como el resto de la barra -- el módulo
# de memoria de al lado dice "used" y el equipo tiene el locale en en_US. Los comentarios,
# en español, igual que el resto del repo.
#
# Salida: una línea JSON para waybar (return-type json). Sin swap devuelve {"text":""},
# que es como waybar esconde un módulo custom: este bloque puede quedarse en el config
# versionado y no molesta en los equipos que no tienen swap configurado.

set -uo pipefail

# nf-fa-exchange (U+F0EC): las dos flechas cruzadas, lo más cercano a "esto se intercambia
# con la RAM". Los iconos de disco quedaban descartados de entrada -- confundirían al zram,
# que ni toca el disco. Entre los varios candidatos con esa misma forma se eligió éste
# mirándolos en la barra: es el único con el mismo grosor de trazo que el micro de #cpu y la
# memoria de #memory, sus dos vecinos, que también son Font Awesome. Las variantes Material
# (nf-md-swap_horizontal y compañía) se ven finitas y pequeñas al lado.
# El glifo está en Symbols Nerd Font, la que va versionada en config_files/fonts, así que se
# ve igual en Arch y en Fedora sin depender del paquete de Font Awesome de cada distro.
ICONO=""

# --- utilidades ----------------------------------------------------------------------
escapar_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | sed -z 's/\n/\\n/g'
}

# El tooltip de waybar lo renderiza pango, que interpreta marcado. Acá no se usa ninguno,
# así que se neutralizan los tres caracteres que lo activan: sin esto, un swapfile en un
# directorio con un '&' en el nombre rompería el parseo y el tooltip saldría en blanco o
# crudo. El '&' va primero, si no se re-escaparían los '&' que introducen los otros dos.
escapar_pango() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# bytes -> "4.0 GiB". Los bytes sueltos van sin decimales, que "12.0 B" no se le dice a nadie.
humano() {
    awk -v b="${1:-0}" 'BEGIN {
        split("B KiB MiB GiB TiB", u, " ")
        i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        if (i == 1) printf "%d %s", b, u[i]
        else        printf "%.1f %s", b, u[i]
    }'
}

# usado total -> porcentaje entero, redondeado. Con total 0 devuelve 0 en vez de romper.
porcentaje() {
    awk -v a="${1:-0}" -v t="${2:-0}" 'BEGIN {
        if (t <= 0) { print 0; exit }
        printf "%d", (a * 100 / t) + 0.5
    }'
}

# /proc/swaps escapa los espacios de los nombres como \040 (un swapfile puede vivir en un
# directorio con espacios). Se deshace sólo para mostrar.
desescapar() {
    printf '%s' "$1" | sed 's/\\040/ /g'
}

# --- zram --------------------------------------------------------------------------
# mm_stat trae, en bytes: orig_data_size compr_data_size mem_used_total (y más campos que
# no se usan). La diferencia entre los tres es TODO el interés de zram:
#   orig       = cuánto creen las aplicaciones que hay guardado
#   compr      = cuánto pesa ya comprimido
#   mem_used   = lo que realmente le cuesta a la RAM, metadatos incluidos
# El ratio se calcula contra mem_used y no contra compr: comprimir 4 GiB a 1 GiB pero
# gastar 1.2 GiB de RAM en lograrlo es un ratio de 3.3x, no de 4x.
zram_bloque() {
    dev="$1"                       # p.ej. "zram0"
    base="/sys/block/$dev"
    prio="$2"
    tam_swap="$3"                  # bytes, según /proc/swaps
    usado="$4"                     # bytes, según /proc/swaps

    algo=""
    if [ -r "$base/comp_algorithm" ]; then
        # El activo es el que viene entre corchetes: "lzo lz4 [zstd] deflate".
        algo=$(sed -n 's/.*\[\([^]]*\)\].*/\1/p' "$base/comp_algorithm")
    fi
    [ -n "$algo" ] && algo=" ($algo)"

    disksize="$tam_swap"
    [ -r "$base/disksize" ] && disksize=$(cat "$base/disksize")

    orig=""; compr=""; mem_used=""
    if [ -r "$base/mm_stat" ]; then
        read -r orig compr mem_used _ < "$base/mm_stat"
    fi

    printf '/dev/%s — zram%s, priority %s\n' "$dev" "$algo" "$prio"
    printf '  Virtual size: %s\n' "$(humano "$disksize")"
    printf '  Used: %s (%s%%)\n' "$(humano "$usado")" "$(porcentaje "$usado" "$tam_swap")"
    if [ -n "$mem_used" ] && [ "$mem_used" -gt 0 ] 2>/dev/null; then
        # El ratio sólo se muestra con algo de carga real: con el zram casi vacío lo único
        # que se está midiendo son los metadatos, y saldría un "0.2x" que asusta y miente.
        if [ "${orig:-0}" -ge 16777216 ] 2>/dev/null; then
            ratio=$(awk -v o="$orig" -v m="$mem_used" 'BEGIN { printf "%.1f", o / m }')
            printf '  Actual RAM taken: %s (%sx compression)\n' "$(humano "$mem_used")" "$ratio"
        else
            printf '  Actual RAM taken: %s\n' "$(humano "$mem_used")"
        fi
    fi
}

# --- partición / archivo -------------------------------------------------------------
disco_bloque() {
    ruta="$1"; tipo="$2"; prio="$3"; tam="$4"; usado="$5"

    case "$tipo" in
        partition) etiqueta="partition" ;;
        file)      etiqueta="file" ;;
        *)         etiqueta="$tipo" ;;
    esac

    printf '%s — %s, priority %s\n' "$(desescapar "$ruta")" "$etiqueta" "$prio"
    printf '  Size: %s\n' "$(humano "$tam")"
    printf '  Used: %s (%s%%)\n' "$(humano "$usado")" "$(porcentaje "$usado" "$tam")"
}

# --- zswap ---------------------------------------------------------------------------
# Devuelve la línea informativa, o nada si el kernel no trae zswap compilado.
zswap_linea() {
    par="/sys/module/zswap/parameters"
    [ -r "$par/enabled" ] || return 0

    if [ "$(cat "$par/enabled")" != "Y" ]; then
        printf 'zswap: off\n'
        return 0
    fi

    compresor=""
    [ -r "$par/compressor" ] && compresor=$(cat "$par/compressor")
    zpool=""
    [ -r "$par/zpool" ] && zpool=" / $(cat "$par/zpool")"
    maximo=""
    [ -r "$par/max_pool_percent" ] && maximo=", up to $(cat "$par/max_pool_percent")% of RAM"

    printf 'zswap: on (%s%s)%s\n' "${compresor:-?}" "$zpool" "$maximo"
    printf '  compressed RAM cache in front of swap; never shows in /proc/swaps\n'
}

# --- lectura de /proc/swaps ----------------------------------------------------------
total_b=0
usado_b=0
detalle=""
hay_zram=0
hay_disco=0

while read -r ruta tipo tam usado prio; do
    # Tamaños de /proc/swaps en bloques de 1 KiB, siempre, sin importar el tamaño de página.
    tam_b=$(( tam * 1024 ))
    usado_b_dev=$(( usado * 1024 ))
    total_b=$(( total_b + tam_b ))
    usado_b=$(( usado_b + usado_b_dev ))

    case "$ruta" in
        /dev/zram*)
            hay_zram=1
            bloque=$(zram_bloque "${ruta#/dev/}" "$prio" "$tam_b" "$usado_b_dev")
            ;;
        *)
            hay_disco=1
            bloque=$(disco_bloque "$ruta" "$tipo" "$prio" "$tam_b" "$usado_b_dev")
            ;;
    esac
    detalle="$detalle$bloque

"
done < <(tail -n +2 /proc/swaps 2>/dev/null)

# Sin swap no hay nada que mostrar y el módulo se esconde solo.
if [ "$total_b" -eq 0 ]; then
    printf '{"text":""}\n'
    exit 0
fi

pct=$(porcentaje "$usado_b" "$total_b")

# El color sigue el mismo criterio que el resto de la barra: sólo grita cuando hay que
# hacer algo. Los umbrales son más altos con zram puro porque llenarlo no significa tocar
# el disco: es RAM comprimida, y el equipo sigue respondiendo.
if [ "$hay_disco" -eq 1 ]; then
    aviso=50; critico=80
else
    aviso=70; critico=90
fi

if   [ "$pct" -ge "$critico" ]; then clase=critical
elif [ "$pct" -ge "$aviso" ];   then clase=warning
else                                 clase=ok
fi

tooltip="Swap: $(humano "$usado_b") / $(humano "$total_b") ($pct% used)

$detalle$(zswap_linea)"

# zswap delante de zram es doble compresión sobre la misma RAM: no ahorra nada y agrega
# trabajo. Si están los dos, conviene decirlo, que es de esas cosas que se configuran una
# vez y no se vuelven a mirar nunca.
if [ "$hay_zram" -eq 1 ] && [ "$hay_disco" -eq 0 ] && [ -r /sys/module/zswap/parameters/enabled ] &&
   [ "$(cat /sys/module/zswap/parameters/enabled)" = "Y" ]; then
    tooltip="$tooltip
  note: with swap only on zram, zswap compresses what is already compressed"
fi

printf '{"text":"%s %s%%","alt":"%s","class":"%s","tooltip":"%s"}\n' \
    "$ICONO" "$pct" \
    "$( [ "$hay_zram" -eq 1 ] && [ "$hay_disco" -eq 0 ] && printf zram || printf disco )" \
    "$clase" \
    "$(escapar_json "$(escapar_pango "$tooltip")")"
