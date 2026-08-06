#!/usr/bin/env bash
#
# Módulo custom/disk de waybar.
#
# En la barra: cuánto hay ocupado y cuánto entra en el filesystem donde vive '/'
# ("17/953G"), que es el disco del que uno se acuerda cuando algo no cabe. En el
# tooltip: TODOS los sistemas de archivos montados, uno por uno.
#
# Por qué un script y no el módulo 'disk' estándar de waybar: ese módulo mira UN
# path y hay que declararlo a mano ("path": "/"), así que en un equipo con /home o
# /var en particiones aparte muestra sólo una y calla las otras -- y la que se llena
# es siempre la otra. Para tener varias habría que repetir el bloque en el config,
# y este archivo es el mismo repo en todos los equipos, donde el particionado no es
# el mismo. Acá se descubre en cada refresco lo que hay montado y no hay nada que
# configurar por máquina.
#
# Qué se muestra y qué no:
#
#   - Un filesystem se cuenta UNA vez, no una por punto de montaje. En btrfs (este
#     equipo) '/', '/home' y '/var/log' son subvolúmenes de la MISMA partición y
#     comparten los mismos 953 GiB; listarlos por separado sería contar cuatro veces
#     el mismo disco y sumar 4 TiB imaginarios. Por eso se agrupa por dispositivo y
#     los montajes van en una línea del bloque. Lo mismo pasa con los bind mounts.
#   - El swap NO aparece, ni siquiera si es una partición: el swap no se monta como
#     filesystem, así que no está en la lista de montajes de donde sale todo esto.
#     No hay nada que filtrar y no hay forma de que se duplique con el módulo de al
#     lado (custom/swap). Un swapFILE sí ocupa lugar en su filesystem y sí se cuenta,
#     que es lo correcto: ese espacio no lo tenés disponible.
#   - Nada de tmpfs, /proc, /sys ni cgroups: son RAM o inventos del kernel, no disco.
#     De eso se encarga el '--real' de findmnt. Se agregan a mano squashfs y erofs
#     (los loops de snap/appimage: son paquetes montados, siempre al 100%, y llenarían
#     el tooltip de ruido) y se exige que el origen sea un /dev/ real -- eso deja
#     afuera los fuse de escritorio (gvfs, portales) sin tener que enumerarlos.
#
# Todo sale de findmnt (util-linux, ya instalado) y de /sys. Sin root.
#
# El texto que se ve va en inglés, como el resto de la barra. Los comentarios en
# español, igual que el resto del repo.
#
# Salida: una línea JSON para waybar (return-type json).

set -uo pipefail

# nf-fa-hard_drive (U+F0A0). Mismo criterio que el icono de custom/swap: se elige de
# Font Awesome y no de Material Design porque sus vecinos en la barra -- el micro de
# #cpu y la memoria de #memory -- son Font Awesome, y las variantes Material se ven
# más finas y chicas al lado. El glifo está en Symbols Nerd Font, la versionada en
# config_files/fonts, así que se ve igual en Arch y en Fedora.
ICONO=""

# Umbrales de color, en porcentaje ocupado. Aplican al filesystem MÁS lleno de los
# internos (ver más abajo), no sólo a '/'.
AVISO=80
CRITICO=90

# --- utilidades ----------------------------------------------------------------------
escapar_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | sed -z 's/\n/\\n/g'
}

# El tooltip lo renderiza pango, que interpreta marcado. Acá no se usa ninguno, así que
# se neutralizan los tres caracteres que lo activan: sin esto, un disco externo con un
# '&' en la etiqueta rompería el parseo y el tooltip saldría en blanco o crudo. El '&'
# va primero, si no se re-escaparían los '&' que introducen los otros dos.
escapar_pango() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# bytes -> "953.0 GiB". Para el tooltip, donde hay lugar para el número completo.
humano() {
    awk -v b="${1:-0}" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", u, " ")
        i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        if (i == 1) printf "%d %s", b, u[i]
        else        printf "%.1f %s", b, u[i]
    }'
}

# usado y total -> "17/953G", para la barra. La unidad la fija el TOTAL y se escribe una
# sola vez al final: el par se lee como una fracción ("17 de 953"), y repetir "G" de los
# dos lados sólo gasta ancho. Los valores chicos llevan un decimal para no mostrar "0/1T"
# con 900 GiB ocupados.
par_compacto() {
    awk -v u="${1:-0}" -v t="${2:-0}" '
        function cifra(x) { return x >= 10 ? sprintf("%d", x + 0.5) : sprintf("%.1f", x) }
        BEGIN {
            split("B K M G T P", n, " ")
            i = 1; d = t
            while (d >= 1024 && i < 6) { d /= 1024; i++ }
            e = 1
            for (j = 1; j < i; j++) e *= 1024
            printf "%s/%s%s", cifra(u / e), cifra(t / e), n[i]
        }'
}

# El porcentaje se calcula usado/(usado+disponible) y NO usado/total, que es lo mismo que
# hace df. La diferencia son los bloques reservados para root: en ext4 son el 5% del disco,
# y contra el total un filesystem que ya NO admite escrituras de usuario marcaría 95% -- se
# vería tranquilo justo cuando dejó de andar. El tamaño que se muestra sí es el total, que
# es el que dice la caja del disco.
porcentaje() {
    awk -v a="${1:-0}" -v d="${2:-0}" 'BEGIN {
        t = a + d
        if (t <= 0) { print 0; exit }
        printf "%d", (a * 100 / t) + 0.5
    }'
}

# findmnt -r escapa los espacios y demás en \xHH (un disco externo puede montarse en
# /run/media/rodrigo/Mi Backup). Se deshace sólo para mostrar.
desescapar() {
    printf '%b' "$1"
}

# --- clasificación de cada filesystem --------------------------------------------------
# Tres grupos, y el grupo decide dos cosas: el orden en el tooltip y si el filesystem
# entra o no en el color del módulo.
#
#   interno    -> el disco del equipo. Es lo único que pinta el módulo: que se llene es
#                 un problema tuyo y de ahora.
#   extraíble  -> pendrive, disco USB, tarjeta SD. Un backup al 98% es un backup, no una
#                 alarma, y desenchufarlo no debería apagar un aviso rojo.
#   red        -> NFS, Samba, sshfs. Ni es tu disco ni lo vaciás vos.
FS_RED="nfs nfs4 cifs smbfs smb3 sshfs fuse.sshfs davfs fuse.davfs ceph fuse.ceph
        glusterfs afs 9p ftpfs curlftpfs fuse.rclone fuse.s3fs"

es_red() {
    case " $(printf '%s' "$FS_RED" | tr -s '[:space:]' ' ') " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}

# 'removable' del disco (no de la partición): para /dev/sda1 el archivo que importa está
# en /sys/block/sda, y a ese directorio se llega con el '..' de la partición -- el kernel
# resuelve primero el symlink de /sys/class/block y recién ahí sube, así que el '..' cae
# en el disco y no en /sys/class. Un disco montado entero (/dev/sdb, sin número) tiene su
# propio archivo, y por eso se prueban los dos caminos en ese orden.
#
# El fallback por punto de montaje cubre lo que sysfs no sabe contestar (LUKS y LVM
# encima de un USB, por ejemplo, donde el dm- no hereda la bandera): udisks monta lo
# extraíble en /run/media, y los escritorios viejos en /media.
leer_sys() {
    local dev="$1" archivo="$2"
    [ -r "/sys/class/block/$dev/$archivo" ] && { cat "/sys/class/block/$dev/$archivo"; return; }
    [ -r "/sys/class/block/$dev/../$archivo" ] && { cat "/sys/class/block/$dev/../$archivo"; return; }
    printf ''
}

# --- lectura de los montajes -----------------------------------------------------------
# SOURCE viene con el subvolumen o el subdirectorio entre corchetes en btrfs y en los bind
# mounts ("/dev/nvme0n1p2[/@home]"). Recortarlo es exactamente lo que agrupa los cuatro
# subvolúmenes de este equipo en un solo bloque.
declare -a fuentes=() tipos=() totales=() usados=() libres=() puntos=() grupos=()
raiz=-1

if ! command -v findmnt >/dev/null 2>&1; then
    printf '{"text":""}\n'
    exit 0
fi

while read -r fuente destino fstipo total usado libre; do
    [ -n "${fuente:-}" ] || continue

    case "$fstipo" in
        squashfs|erofs|overlay|ramfs) continue ;;
    esac

    fuente="${fuente%%\[*}"

    # Origen real o filesystem de red declarado. zfs se nombra aparte porque sus datasets
    # se llaman "tanque/casa" y no /dev/nada, y aun así son el disco de la máquina.
    if [ "${fuente#/dev/}" = "$fuente" ] && [ "$fstipo" != "zfs" ] && ! es_red "$fstipo"; then
        continue
    fi

    # Un filesystem sin tamaño no es un disco montado: es un fuse que no contesta statvfs,
    # o un montaje en pleno armado. Mostrarlo sería una línea de ceros.
    [ "${total:-0}" -gt 0 ] 2>/dev/null || continue

    # ¿Ya está este dispositivo? Entonces esto es otro subvolumen o un bind: sólo suma
    # punto de montaje.
    ya=-1
    for i in "${!fuentes[@]}"; do
        [ "${fuentes[$i]}" = "$fuente" ] && { ya=$i; break; }
    done
    if [ "$ya" -ge 0 ]; then
        puntos[$ya]="${puntos[$ya]}, $(desescapar "$destino")"
        [ "$destino" = "/" ] && raiz=$ya
        continue
    fi

    grupo=interno
    if es_red "$fstipo"; then
        grupo=red
    else
        dev="${fuente#/dev/}"
        # /dev/mapper/algo es un symlink a /dev/dm-N, y el nombre que entiende sysfs es
        # el segundo.
        [ -L "$fuente" ] && dev=$(basename "$(readlink -f "$fuente")")
        case "$(leer_sys "$dev" removable)" in
            1) grupo=extraible ;;
        esac
        case "$(desescapar "$destino")" in
            /run/media/*|/media/*) grupo=extraible ;;
        esac
    fi

    fuentes+=("$fuente")
    tipos+=("$fstipo")
    totales+=("$total")
    usados+=("$usado")
    libres+=("$libre")
    puntos+=("$(desescapar "$destino")")
    grupos+=("$grupo")

    [ "$destino" = "/" ] && raiz=$(( ${#fuentes[@]} - 1 ))
done < <(findmnt -rnb -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL --real 2>/dev/null)

# Sin nada que mostrar el módulo se esconde solo, igual que custom/swap y custom/rclone.
if [ "${#fuentes[@]}" -eq 0 ] || [ "$raiz" -lt 0 ]; then
    printf '{"text":""}\n'
    exit 0
fi

# --- el número de la barra: el filesystem de '/' ---------------------------------------
pct_raiz=$(porcentaje "${usados[$raiz]}" "${libres[$raiz]}")
texto="$ICONO $(par_compacto "${usados[$raiz]}" "${totales[$raiz]}")"

# --- el color: el interno más lleno ----------------------------------------------------
# No alcanza con mirar '/': en un equipo con /home aparte, el disco que se llena es
# justamente el que no está en la barra, y el módulo se quedaría en verde mientras no
# entra un archivo más. Cuando el que manda no es '/', el tooltip lo dice con nombre y
# apellido -- si no, sería un módulo rojo mostrando un 12%.
peor=-1
peor_pct=-1
for i in "${!fuentes[@]}"; do
    [ "${grupos[$i]}" = "interno" ] || continue
    p=$(porcentaje "${usados[$i]}" "${libres[$i]}")
    if [ "$p" -gt "$peor_pct" ]; then
        peor_pct=$p
        peor=$i
    fi
done

if   [ "$peor_pct" -ge "$CRITICO" ]; then clase=critical
elif [ "$peor_pct" -ge "$AVISO" ];   then clase=warning
else                                      clase=ok
fi

# --- tooltip ---------------------------------------------------------------------------
bloque() {
    local i="$1" marca="" dev p
    case "${grupos[$i]}" in
        extraible) marca=" (removable)" ;;
        red)       marca=" (network)" ;;
        interno)
            # El disco giratorio se avisa y el SSD no: en un equipo con los dos, saber
            # cuál es cuál explica por qué una carpeta abre lento. Lo normal hoy es el
            # SSD, y marcar lo normal es ruido.
            dev="${fuentes[$i]#/dev/}"
            [ -L "${fuentes[$i]}" ] && dev=$(basename "$(readlink -f "${fuentes[$i]}")")
            [ "$(leer_sys "$dev" queue/rotational)" = "1" ] && marca=" (HDD)"
            ;;
    esac

    p=$(porcentaje "${usados[$i]}" "${libres[$i]}")
    printf '%s — %s, %s%s\n' "${fuentes[$i]}" "${tipos[$i]}" "$(humano "${totales[$i]}")" "$marca"
    printf '  Used: %s (%s%%) — %s free\n' \
        "$(humano "${usados[$i]}")" "$p" "$(humano "${libres[$i]}")"
    printf '  Mounted at: %s\n' "${puntos[$i]}"
}

detalle=""
# '/' primero y después el resto en orden de montaje, que es el orden en que uno los
# piensa (/ , /boot, /home...). Los extraíbles y la red van al final: son visitas.
for grupo in interno extraible red; do
    for i in "${!fuentes[@]}"; do
        [ "${grupos[$i]}" = "$grupo" ] || continue
        [ "$grupo" = "interno" ] && [ "$i" -eq "$raiz" ] && continue
        detalle="$detalle$(bloque "$i")

"
    done
    [ "$grupo" = "interno" ] && detalle="$(bloque "$raiz")

$detalle"
done

tooltip="Disk: $(humano "${usados[$raiz]}") / $(humano "${totales[$raiz]}") ($pct_raiz% used) — /

${detalle%$'\n\n'}"

if [ "$peor" -ge 0 ] && [ "$peor" -ne "$raiz" ] && [ "$peor_pct" -ge "$AVISO" ]; then
    tooltip="$tooltip

  note: ${puntos[$peor]%%,*} is the fullest filesystem ($peor_pct% used); the bar shows /"
fi

printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
    "$texto" "$clase" "$clase" \
    "$(escapar_json "$(escapar_pango "$tooltip")")"
