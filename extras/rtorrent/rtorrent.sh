#!/usr/bin/env bash
# Instala o desinstala rTorrent, el cliente BitTorrent de ncurses, con una config
# propia y una carpeta de descargas dedicada.
#
# Vive en extras/ porque NO es parte del entorno base que arma archdesktopinstall.sh:
# se corre a mano en las máquinas donde haga falta.
#
#   ./rtorrent/rtorrent.sh install     # instala, crea las carpetas y copia la config
#   ./rtorrent/rtorrent.sh uninstall   # da de baja el paquete y la config; las descargas quedan
#   ./rtorrent/rtorrent.sh status      # qué hay instalado, dónde y en qué estado
#   ./rtorrent/rtorrent.sh             # menú interactivo con esas tres opciones
#
# A diferencia de dotconfig/, la config se COPIA en vez de enlazarse. Es a propósito:
# esto es un extra opcional, y un symlink dejaría a ~/.config/rtorrent/ apuntando a un
# repo que en esa máquina puede no existir. La contra es que editar el .rc del repo no
# se refleja solo: hay que volver a correr 'install' (es idempotente). 'status' avisa
# cuando la copia desplegada quedó distinta de la del repo.
#
# Los comentarios van en español como el resto del repo; los mensajes en inglés.

set -euo pipefail

morir()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
aviso()  { printf '\033[33m->\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m->\033[0m %s\n' "$*"; }

# pacman necesita sudo puntual; como root, las carpetas de descarga y la config se
# crearían con dueño root dentro de /root. Mismo criterio que docker.sh.
[ "$EUID" -eq 0 ] && morir "do not run this as root/sudo; it will ask for sudo when needed."

PAQUETES=(
    rtorrent  # El cliente. Arrastra libtorrent (la librería del mismo autor, con la versión clavada), curl y tinyxml2 como dependencias, así que no hay que listarlas.
)

# El .rc fuente vive al lado de este script para que se versione y se pueda diffear
# contra lo desplegado. La ruta se resuelve desde el script y no desde $PWD, así
# funciona igual invocado como ./rtorrent.sh o como extras/rtorrent/rtorrent.sh.
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RC_FUENTE="$AQUI/rtorrent.rc"

# rTorrent 0.16 busca la config en este orden: $XDG_CONFIG_HOME/rtorrent/rtorrent.rc
# y después ~/.rtorrent.rc (verificado en los strings del binario). Se usa la primera,
# que es la ubicación XDG moderna; la vieja ~/.rtorrent.rc queda libre.
RC_DESTINO="${XDG_CONFIG_HOME:-$HOME/.config}/rtorrent/rtorrent.rc"

# Estas rutas están DUPLICADAS en rtorrent.rc, que las arma con (system.env,HOME).
# No hay forma de tener una sola fuente sin generar el .rc con sed, y eso rompería
# el diff contra el repo que hace 'status'. Si cambiás una, cambiá la otra.
BASE="$HOME/Downloads/rtorrent"
DIR_DESCARGAS=("$BASE/downloads" "$BASE/watch")
ESTADO="$HOME/.local/state/rtorrent"

# ==========================================
# ESTADO
# ==========================================
estado() {
    printf '\n\033[1m=== rTorrent status ===\033[0m\n\n'

    printf '%-12s %s\n' "PACKAGE" "INSTALLED"
    local p v
    for p in "${PAQUETES[@]}"; do
        v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}') || true
        printf '%-12s %s\n' "$p" "${v:--}"
    done
    v=$(pacman -Q libtorrent 2>/dev/null | awk '{print $2}') || true
    printf '%-12s %s\n' "libtorrent" "${v:--} (dependency)"

    printf '\n'
    if [ -f "$RC_DESTINO" ]; then
        # cmp en vez de diff: sólo interesa el sí/no, y no hay que imprimir el
        # contenido de un archivo que puede tener rutas privadas.
        if cmp -s "$RC_FUENTE" "$RC_DESTINO"; then
            printf 'config      : %s (matches the repo copy)\n' "$RC_DESTINO"
        else
            printf 'config      : %s \033[33m(DIFFERS from the repo copy)\033[0m\n' "$RC_DESTINO"
            printf '              diff %s %s\n' "$RC_FUENTE" "$RC_DESTINO"
        fi
    else
        printf 'config      : not installed\n'
    fi

    # La config vieja gana si existe? No: rTorrent prueba la XDG primero. Pero si
    # quedó una de una instalación manual anterior, conviene saberlo.
    [ -f "$HOME/.rtorrent.rc" ] && \
        printf '            \033[33mnote: ~/.rtorrent.rc also exists (unused; XDG path wins)\033[0m\n'

    printf '\n'
    # Las rutas se acortan con ~ para que la columna de tamaño no se desalinee: en
    # este repo $HOME siempre es largo y empujaría el valor fuera del ancho fijo.
    local d
    for d in "${DIR_DESCARGAS[@]}" "$ESTADO/session"; do
        if [ -d "$d" ]; then
            printf '%-34s %s\n' "${d/#$HOME/\~}" "$(du -sh "$d" 2>/dev/null | cut -f1)"
        else
            printf '%-34s %s\n' "${d/#$HOME/\~}" "(does not exist yet)"
        fi
    done

    printf '\n'
    if pgrep -x rtorrent > /dev/null 2>&1; then
        printf 'process     : running (pid %s)\n' "$(pgrep -x rtorrent | tr '\n' ' ')"
    else
        printf 'process     : not running\n'
    fi
    printf '\n'
}

# ==========================================
# INSTALAR
# ==========================================
instalar() {
    [ -f "$RC_FUENTE" ] || morir "config template not found: $RC_FUENTE"

    sudo -v

    aviso "Installing packages..."
    sudo pacman -S --needed --noconfirm "${PAQUETES[@]}"

    # Las carpetas se crean ANTES de copiar la config: rTorrent no crea el directorio
    # de sesión por su cuenta y aborta al arrancar si no existe.
    aviso "Creating directories..."
    mkdir -p "${DIR_DESCARGAS[@]}" "$ESTADO/session"
    local d
    for d in "${DIR_DESCARGAS[@]}" "$ESTADO/session"; do
        printf '   %s\n' "$d"
    done

    # Si ya hay una config y no es la nuestra, se respalda con timestamp en vez de
    # pisarla. Mismo criterio que archdesktopinstall.sh con los dotfiles: reinstalar
    # nunca debe perder ediciones a mano.
    if [ -f "$RC_DESTINO" ] && ! cmp -s "$RC_FUENTE" "$RC_DESTINO"; then
        local respaldo="$RC_DESTINO.bak.$(date +%Y%m%d%H%M%S)"
        cp -a "$RC_DESTINO" "$respaldo"
        aviso "Existing config differed; backed up as $respaldo"
    fi
    install -Dm644 "$RC_FUENTE" "$RC_DESTINO"
    ok "Config installed: $RC_DESTINO"

    printf '\n'
    ok "Done. Typical usage:"
    aviso "  rtorrent                           # opens the ncurses UI"
    aviso "  cp foo.torrent $BASE/watch/        # loads and starts on its own"
    printf '\n'
    aviso "Keys: this config uses the VI keymap (j/k to move, not the arrows)."
    aviso "  backspace  add a torrent by URL or path      ^s  start      ^d  stop / delete"
    aviso "  ^q         quit                              ^o  change destination directory"
    printf '\n'
    aviso "Downloads land in $BASE/downloads/. Log: $ESTADO/rtorrent.log"
}

# ==========================================
# DESINSTALAR
# ==========================================
desinstalar() {
    # Bajar el paquete con rTorrent corriendo deja la sesión a medio guardar y puede
    # perder el estado de los torrents activos.
    if pgrep -x rtorrent > /dev/null 2>&1; then
        morir "rtorrent is running. Quit it first (^q inside the UI) and re-run."
    fi

    local confirmar
    read -rp "Remove rTorrent and its config? Downloads are kept. [y/N]: " confirmar
    [[ "$confirmar" =~ ^[yYsS]$ ]] || { aviso "Cancelled."; exit 0; }

    sudo -v

    # Se desinstala sólo lo presente: correr uninstall dos veces, o tras una
    # instalación a medias, no debe morir en pacman por un paquete inexistente.
    local instalados=() p
    for p in "${PAQUETES[@]}"; do
        pacman -Qq "$p" &> /dev/null && instalados+=("$p")
    done
    if [ "${#instalados[@]}" -eq 0 ]; then
        aviso "No packages from the stack are installed; nothing to remove."
    else
        aviso "Removing: ${instalados[*]}"
        # -Rns arrastra libtorrent y demás dependencias que queden huérfanas.
        sudo pacman -Rns --noconfirm "${instalados[@]}"
    fi

    # La config SÍ se borra (es lo que instaló este script), pero si la editaste a
    # mano se respalda en vez de perderse. Borrar el trabajo de alguien sin avisar
    # es peor que dejar un archivo de más.
    if [ -f "$RC_DESTINO" ]; then
        if cmp -s "$RC_FUENTE" "$RC_DESTINO"; then
            rm -f "$RC_DESTINO"
            ok "Config removed: $RC_DESTINO"
        else
            local respaldo="$RC_DESTINO.bak.$(date +%Y%m%d%H%M%S)"
            mv "$RC_DESTINO" "$respaldo"
            aviso "Config had local edits; kept as $respaldo instead of deleting it."
        fi
        # rmdir y no rm -rf: si quedó algo más adentro (el respaldo de arriba, o
        # archivos de otra herramienta), el directorio se conserva sin chistar.
        rmdir "$(dirname "$RC_DESTINO")" 2> /dev/null || true
    else
        aviso "No config at $RC_DESTINO; nothing to remove."
    fi

    printf '\n'
    ok "Uninstalled. These were kept on purpose:"
    aviso "  $BASE/   your downloads and the watch folder"
    aviso "  $ESTADO/   session state and log: the list of torrents rTorrent had loaded"
    aviso "Delete them by hand if you want the disk space back:"
    aviso "  rm -rf $BASE $ESTADO"
}

# ==========================================
# ENTRADA
# ==========================================
case "${1:-}" in
    install)   instalar ;;
    uninstall) desinstalar ;;
    status)    estado ;;
    "")
        printf '\n\033[1m=== rTorrent (ncurses BitTorrent client) ===\033[0m\n'
        printf '  1) Install\n  2) Uninstall\n  3) Status\n  q) Quit\n\n'
        read -rp "Choice: " opcion
        case "${opcion:-}" in
            1) instalar ;;
            2) desinstalar ;;
            3) estado ;;
            *) aviso "Bye." ;;
        esac
        ;;
    *) morir "usage: $0 [install|uninstall|status]" ;;
esac
