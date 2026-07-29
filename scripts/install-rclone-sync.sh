#!/usr/bin/env bash
# Instala o desinstala rclone-sync en esta máquina: paquete, symlinks y servicio.
#
#   bash ~/config_files/scripts/install-rclone-sync.sh                menú
#   bash ~/config_files/scripts/install-rclone-sync.sh --instalar
#   bash ~/config_files/scripts/install-rclone-sync.sh --desinstalar
#
# Instalar es idempotente: reejecutarlo sólo repone lo que falte. Corrélo también en el
# SEGUNDO computador -- ahí lo único que vas a querer revisar es ~/.config/rclone-sync.conf,
# que es el archivo donde vive lo propio de cada equipo y que este script crea vacío la
# primera vez.
#
# EL ICONO DE LA BARRA
# No se toca acá. El módulo custom/rclone vive en dotconfig/waybar/config.jsonc, que está
# VERSIONADO y llega por symlink a ~/.config/waybar en todos los equipos: si la
# desinstalación editara ese archivo para sacar el módulo, el cambio viajaría por git y
# el siguiente pull le borraría el icono también al otro computador. En vez de eso el
# módulo se queda quieto y 'rclone-sync status' devuelve texto vacío cuando no está
# instalado, que es como waybar oculta un módulo custom. El icono aparece al instalar y
# desaparece al desinstalar, sin que ningún archivo del repo cambie. Ver esta_instalado()
# en el script.
#
# Vive en scripts/ y no en bin_configs/ porque no es un comando de uso diario sino un
# instalador, igual que link-bins.sh e install-fonts.sh. El que SÍ queda como comando es
# 'rclone-sync', que este script enlaza en ~/.local/bin (ya está en el PATH del zshrc).

set -e

repo="$HOME/config_files/scripts"
script="$repo/rclone-sync"
unit="$repo/rclone-sync.service"
conf_local="${XDG_CONFIG_HOME:-$HOME/.config}/rclone-sync.conf"
enlace_bin="$HOME/.local/bin/rclone-sync"

# Valores por defecto, luego los .conf los pisan. Se cargan acá arriba porque tanto
# instalar como desinstalar necesitan saber de qué carpeta y de qué remoto se habla.
DIR_LOCAL="$HOME/home-laptop"; REMOTO="gdrive:/home-laptop"; INTERVALO=60; SENAL_WAYBAR=8
# shellcheck source=/dev/null
[ -r "$repo/rclone-sync.conf" ] && . "$repo/rclone-sync.conf"
# shellcheck source=/dev/null
[ -r "$conf_local" ] && . "$conf_local"

# El mismo mecanismo que usa el script para decidir si se dibuja en la barra. Repetido
# acá y no importado porque el instalador tiene que poder hablar de un rclone-sync que
# todavía no está instalado.
esta_instalado() {
    command -v rclone >/dev/null 2>&1 && [ -e "$enlace_bin" ]
}

# Que el icono aparezca o desaparezca en el acto y no en la próxima vuelta del "interval"
# del módulo (30s). Es la misma señal que usa el propio rclone-sync.
refrescar_waybar() {
    pkill -x -RTMIN+"$SENAL_WAYBAR" waybar 2>/dev/null || true
}

# --------------------------------------------------------------------------
# Instalar
# --------------------------------------------------------------------------
instalar() {
    echo "-> Instalando rclone-sync..."
    echo

    [ -f "$script" ] || { echo "ERROR: no existe $script"; exit 1; }
    # git no siempre trae el bit de ejecución en un clone limpio.
    chmod +x "$script"

    # 1) El paquete
    #
    # Instalarlo acá y no sólo avisar que falta: en un equipo nuevo esto es el primer
    # paso obligado, y hacerlo a mano no aporta ninguna decisión que valga la pena.
    if command -v rclone >/dev/null 2>&1; then
        echo "-> rclone ya está instalado ($(rclone version 2>/dev/null | head -n1))"
    else
        command -v pacman >/dev/null 2>&1 || {
            echo "ERROR: rclone no está instalado y esta máquina no usa pacman."
            echo "       Instalalo con el gestor de paquetes que corresponda y reintentá."
            exit 1
        }
        echo "-> rclone no está instalado; instalándolo con pacman (pide sudo)."
        sudo pacman -S --needed rclone || {
            echo "ERROR: falló la instalación de rclone. No sigo."
            exit 1
        }
        echo "-> rclone instalado"
    fi

    # 2) El remoto
    #
    # Lo único que este script NO puede hacer por vos: 'rclone config' es OAuth contra
    # Google y necesita un navegador. Falla ACÁ con un mensaje claro en vez de dentro del
    # demonio, donde el síntoma sería un icono rojo y un log que hay que ir a buscar.
    nombre_remoto="${REMOTO%%:*}"
    if ! rclone listremotes | grep -qx "$nombre_remoto:"; then
        echo
        echo "ERROR: el remoto '$nombre_remoto:' no está configurado en rclone."
        echo "       Configuralo con:  rclone config"
        echo "       Remotos que sí existen:"
        rclone listremotes | sed 's/^/         /'
        exit 1
    fi
    echo "-> Remoto '$nombre_remoto:' configurado"

    # 3) La carpeta local
    if [ ! -d "$DIR_LOCAL" ]; then
        echo "-> La carpeta local $DIR_LOCAL no existe; creándola."
        mkdir -p "$DIR_LOCAL"
    fi

    # 4) El comando en el PATH
    #
    # Este symlink es además la MARCA de instalado que mira 'rclone-sync status' para
    # decidir si se dibuja en la barra. Borrarlo es lo que apaga el icono.
    mkdir -p "$(dirname "$enlace_bin")"
    ln -sfn "$script" "$enlace_bin"
    echo "-> $enlace_bin -> $script"

    # 5) Configuración propia de esta máquina
    #
    # Se crea COMENTADA a propósito: si el archivo trajera valores activos duplicaría el
    # .conf del repo, y a la larga tendrías dos fuentes de verdad desincronizadas. Acá
    # sólo se descomenta lo que este equipo necesite distinto.
    if [ ! -f "$conf_local" ]; then
        cat >"$conf_local" <<EOF
# Ajustes de rclone-sync PROPIOS DE ESTA MÁQUINA ($(uname -n)).
# Se lee después de config_files/scripts/rclone-sync.conf y pisa sus valores.
# No está en git: es el lugar correcto para todo lo que difiera entre computadores.
#
# Descomentá sólo lo que necesites cambiar acá.

#DIR_LOCAL="\$HOME/home-laptop"
#REMOTO="gdrive:/home-laptop"
#INTERVALO=60
#NOTIFICAR=1
EOF
        echo "-> Creado $conf_local (todo comentado: hereda los valores del repo)"
    else
        echo "-> $conf_local ya existe, no se toca"
    fi

    # 6) Servicio de usuario
    #
    # 'enable' con ruta ABSOLUTA: systemd crea él mismo el symlink en
    # ~/.config/systemd/user/ apuntando al unit del repo. Así el unit versionado es la
    # única copia y un 'git pull' que lo modifique aplica al reiniciar el servicio, sin
    # tener que volver a copiar nada.
    systemctl --user daemon-reload
    systemctl --user enable --now "$unit"
    echo "-> Servicio habilitado y arrancado"

    refrescar_waybar

    # 7) Verificación
    echo
    sleep 2
    if systemctl --user is-active --quiet rclone-sync.service; then
        echo "   Estado del servicio: activo"
    else
        echo "   ATENCIÓN: el servicio NO quedó activo. Mirá:"
        echo "     systemctl --user status rclone-sync.service"
        echo "     rclone-sync log"
    fi

    echo
    echo "   Carpeta:  $DIR_LOCAL"
    echo "   Remoto:   $REMOTO"
    echo "   Cada:     ${INTERVALO}s   (se cambia en $conf_local, sin reiniciar nada)"
    echo
    echo "   La PRIMERA sincronización hace un --resync: reconstruye la línea base"
    echo "   comparando los dos lados enteros. Tarda más que las siguientes y no borra"
    echo "   nada -- en los conflictos gana el archivo más nuevo."
    echo
    echo "   Menú (activar/desactivar):  rclone-sync menu   -- o clic en el icono de la barra"
    echo "   Ver qué está pasando:       rclone-sync log"
    echo "   Sincronizar ahora:          rclone-sync once"
    echo
    echo "   El icono ya tendría que estar en la barra. Si no aparece, recargala:"
    echo "     pkill -SIGUSR2 waybar"
}

# --------------------------------------------------------------------------
# Desinstalar
# --------------------------------------------------------------------------
desinstalar() {
    echo "-> Desinstalando rclone-sync..."
    echo

    # 1) Parar el servicio ANTES que nada. Sacarle el binario a un bisync en curso sería
    # la peor forma de interrumpirlo: 'disable --now' le manda TERM y el trap del demonio
    # deja el estado escrito y suelta el lock como corresponde.
    if systemctl --user is-active --quiet rclone-sync.service; then
        echo "-> El servicio está corriendo; deteniéndolo."
    fi
    systemctl --user disable --now rclone-sync.service 2>/dev/null || true
    systemctl --user daemon-reload
    echo "-> Servicio detenido y deshabilitado"

    # 2) El symlink. Esto es lo que APAGA EL ICONO: sin él, 'rclone-sync status' devuelve
    # texto vacío y waybar oculta el módulo, sin tocar ningún archivo del repo.
    rm -f "$enlace_bin"
    refrescar_waybar
    echo "-> Symlink eliminado; el icono desaparece de la barra"

    # 3) El paquete
    #
    # Se pregunta porque rclone puede estar sirviendo para otras cosas en esta máquina
    # (otros remotos, un mount, scripts propios), y eso el instalador no lo puede saber.
    if command -v rclone >/dev/null 2>&1; then
        echo
        printf '¿Eliminar también el paquete rclone del sistema? [S/n] '
        read -r resp || resp=""
        case "$resp" in
            n|N|no|NO) echo "-> Se deja rclone instalado" ;;
            *)
                if command -v pacman >/dev/null 2>&1; then
                    # Sin 'set -e': si otro paquete depende de rclone, pacman se niega, y
                    # eso es información para vos, no un motivo para abortar lo que queda.
                    if sudo pacman -Rns rclone; then
                        echo "-> Paquete rclone eliminado"
                    else
                        echo "   ATENCIÓN: pacman no pudo eliminar rclone (¿algo depende de él?)."
                        echo "   El resto de la desinstalación sí se completó."
                    fi
                else
                    echo "   Esta máquina no usa pacman; eliminá rclone a mano."
                fi ;;
        esac
    fi

    # 4) Qué sobrevive, y por qué. Nada de esto lo puede rehacer el instalador, así que
    # borrarlo sin preguntar convertiría una desinstalación en una pérdida de datos.
    echo
    echo "   NO se tocó:"
    echo "     $DIR_LOCAL   (tus archivos, y su copia en $REMOTO)"
    echo "     ~/.config/rclone/rclone.conf   (el remoto y sus credenciales)"
    echo "     $conf_local"
    echo "     ~/.cache/rclone-sync   (log y línea base de bisync)"
    echo
    echo "   Para volver a instalarlo, este mismo script. Si borraste el paquete pero no"
    echo "   rclone.conf, el remoto sigue ahí y no hace falta rehacer el 'rclone config'."
}

# --------------------------------------------------------------------------
# Menú
# --------------------------------------------------------------------------
menu() {
    echo
    echo "  rclone-sync -- sincronización bidireccional con $REMOTO"
    echo
    if esta_instalado; then
        if systemctl --user is-active --quiet rclone-sync.service; then
            echo "  Estado actual: INSTALADO, servicio corriendo"
        else
            echo "  Estado actual: INSTALADO, servicio detenido"
        fi
    else
        echo "  Estado actual: NO instalado en esta máquina"
    fi
    echo
    echo "    1) Instalar     (paquete + servicio + icono en la barra)"
    echo "    2) Desinstalar  (detiene el servicio, saca el icono y elimina rclone)"
    echo "    q) Salir"
    echo
    printf '  Opción: '
    read -r opcion || opcion=q
    echo
    case "$opcion" in
        1) instalar ;;
        2) desinstalar ;;
        q|Q|"") echo "  Nada que hacer." ;;
        *) echo "  Opción desconocida: $opcion"; exit 1 ;;
    esac
}

# --------------------------------------------------------------------------
case "${1:-}" in
    --instalar|instalar|-i)       instalar ;;
    --desinstalar|desinstalar|-d) desinstalar ;;
    "")                           menu ;;
    *)
        cat <<EOF
uso: install-rclone-sync.sh [--instalar|--desinstalar]

  (sin argumentos)  menú con las dos opciones
  --instalar        instala rclone si falta, enlaza el comando, crea la config de esta
                    máquina, habilita el servicio y hace aparecer el icono en waybar
  --desinstalar     detiene el servicio, saca el icono de waybar y ofrece eliminar el
                    paquete rclone. No borra tus archivos ni el remoto configurado.
EOF
        exit 1 ;;
esac
