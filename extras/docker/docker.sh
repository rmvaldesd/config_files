#!/usr/bin/env bash
# Instala o desinstala Docker con todo lo necesario para levantar servicios desde
# archivos docker-compose.yaml.
#
# Vive en extras/ porque NO es parte del entorno base que arma archdesktopinstall.sh:
# se corre a mano en las máquinas donde haga falta.
#
#   ./docker/docker.sh install     # instala, habilita el demonio y te suma al grupo docker
#   ./docker/docker.sh uninstall   # da de baja todo; imágenes y volúmenes se conservan
#   ./docker/docker.sh status      # qué hay instalado y en qué estado
#   ./docker/docker.sh             # menú interactivo con esas tres opciones
#
# Los comentarios van en español como el resto del repo; los mensajes en inglés.

set -euo pipefail

morir()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
aviso()  { printf '\033[33m->\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m->\033[0m %s\n' "$*"; }

# usermod necesita un usuario real; como root sumaría a root al grupo docker en vez
# de a vos. Mismo criterio que archdesktopinstall.sh y virtualization.sh.
[ "$EUID" -eq 0 ] && morir "do not run this as root/sudo; it will ask for sudo when needed."

PAQUETES=(
    docker          # El demonio (dockerd + containerd), el CLI y las units docker.service/.socket.
    docker-compose  # El plugin Compose v2: habilita 'docker compose up' y compañía, que es como se consumen los docker-compose.yaml. El binario suelto 'docker-compose' (v1, python) ya no existe; este paquete provee el subcomando.
    docker-buildx   # Backend moderno de build (BuildKit). 'docker compose build' y los Dockerfiles con features nuevas (cache mounts, multi-stage paralelo) lo esperan presente.
)

# ==========================================
# ESTADO
# ==========================================
estado() {
    printf '\n\033[1m=== Docker stack status ===\033[0m\n\n'

    printf '%-16s %s\n' "PACKAGE" "INSTALLED"
    local p v
    for p in "${PAQUETES[@]}"; do
        v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}') || true
        printf '%-16s %s\n' "$p" "${v:--}"
    done

    printf '\n'
    # is-active imprime el estado también cuando falla; sólo si vino vacío va el placeholder.
    local srv sck modo
    srv=$(systemctl is-active docker.service 2>/dev/null || true)
    sck=$(systemctl is-enabled docker.socket 2>/dev/null || true)
    # Qué se habilitó decide el modo: el .socket habilitado (con el .service no)
    # significa arranque bajo demanda.
    if [ "$(systemctl is-enabled docker.service 2>/dev/null || true)" = "enabled" ]; then
        modo="at boot (docker.service)"
    elif [ "$sck" = "enabled" ]; then
        modo="on demand (docker.socket)"
    else
        modo="not enabled"
    fi
    printf 'docker service : %s\n' "${srv:-not-found}"
    printf 'start mode     : %s\n' "$modo"
    if id -nG "$USER" | grep -qw docker; then
        printf 'docker group   : %s is a member\n' "$USER"
    else
        printf 'docker group   : %s is NOT a member (docker commands will need sudo)\n' "$USER"
    fi

    # Sólo consulta el demonio si está corriendo y hay permisos; un status nunca
    # debe pedir password ni arrancar nada.
    if command -v docker > /dev/null && systemctl is-active --quiet docker.service && id -nG "$USER" | grep -qw docker; then
        printf '\n'
        docker ps --format 'running: {{.Names}} ({{.Image}})' 2>/dev/null || true
        printf 'containers: %s running, images: %s\n' \
            "$(docker ps -q 2>/dev/null | grep -c . || echo '?')" \
            "$(docker image ls -q 2>/dev/null | sort -u | grep -c . || echo '?')"
    fi
    printf '\n'
}

# ==========================================
# INSTALAR
# ==========================================
instalar() {
    # podman-docker provee /usr/bin/docker y conflictúa con el paquete docker: con
    # --noconfirm pacman respondería NO al prompt de reemplazo y moriría a mitad de
    # transacción. Mismo criterio que el precheck de audio del instalador principal.
    if pacman -Qq podman-docker &> /dev/null; then
        morir "podman-docker is installed and conflicts with docker.
       Remove it first and re-run:  sudo pacman -Rns podman-docker"
    fi

    sudo -v

    aviso "Installing packages..."
    sudo pacman -S --needed --noconfirm "${PAQUETES[@]}"

    # Dos modos de arranque, con un tradeoff real que decide el usuario:
    #
    #   .service : dockerd corre desde el boot. Los contenedores con
    #              'restart: always/unless-stopped' vuelven solos tras un reboot.
    #              Costo medido en este equipo: ~100 MB de RAM (dockerd +
    #              containerd) y ~1s de arranque, permanentes.
    #
    #   .socket  : systemd escucha /run/docker.sock SIN el demonio corriendo y lo
    #              arranca solo cuando algo se conecta (el primer 'docker ...').
    #              Es transparente salvo un retardo mínimo en ese primer comando.
    #              A cambio, tras un reboot NADA vuelve por sí solo: los
    #              'restart: always' esperan a que toques el CLI.
    #
    # Ojo: el socket arranca bajo demanda pero NO apaga al quedar ocioso; una vez
    # levantado sigue vivo hasta el próximo reboot.
    printf '\n'
    aviso "Start mode:"
    printf '  1) At boot (docker.service) - containers with restart: always come back after a reboot\n'
    printf '  2) On demand (docker.socket) - daemon starts on first use; nothing auto-restarts after a reboot\n\n'
    local modo
    read -rp "Choice [1]: " modo || true
    if [ "${modo:-1}" = "2" ]; then
        aviso "Enabling docker.socket (on demand)..."
        # El disable del .service es por si se corre install de nuevo para cambiar
        # de modo: sin esto quedarían los dos habilitados y ganaría el del boot.
        sudo systemctl disable --now docker.service 2> /dev/null || true
        sudo systemctl enable --now docker.socket
    else
        aviso "Enabling docker.service (at boot)..."
        sudo systemctl enable --now docker.service
    fi

    # El grupo docker permite usar el CLI sin sudo. OJO: es equivalente a root
    # (quien habla con el socket puede montar / dentro de un contenedor); es el
    # tradeoff estándar y consciente para una máquina de desarrollo personal.
    if id -nG "$USER" | grep -qw docker; then
        ok "$USER already in the docker group."
    else
        sudo usermod -aG docker "$USER"
        ok "$USER added to the docker group. LOG OUT AND BACK IN for it to take effect."
    fi

    # Smoke test opcional: valida demonio, red y registry de una. Va con sudo
    # porque el grupo recién agregado todavía no aplica en esta sesión.
    local probar
    printf '\n'
    read -rp "Run 'sudo docker run --rm hello-world' as a smoke test? [y/N]: " probar || true
    if [[ "${probar:-}" =~ ^[yYsS]$ ]]; then
        sudo docker run --rm hello-world && ok "Smoke test passed." \
            || aviso "Smoke test failed; check 'systemctl status docker' and your network."
    fi

    printf '\n'
    ok "Done. After re-login, typical usage:"
    aviso "  docker compose up -d      # in a directory with docker-compose.yaml"
    aviso "  docker compose down"
    aviso "Note: it's 'docker compose' (v2 subcommand); the old 'docker-compose' v1 binary no longer exists."
}

# ==========================================
# DESINSTALAR
# ==========================================
desinstalar() {
    # Con contenedores corriendo, tirar el demonio abajo los mata sin apagado limpio.
    if command -v docker > /dev/null && systemctl is-active --quiet docker.service; then
        local corriendo
        corriendo=$(sudo docker ps -q 2>/dev/null | grep -c . || true)
        if [ "${corriendo:-0}" -gt 0 ]; then
            sudo docker ps 2>/dev/null || true
            morir "there are running containers. Stop them first: docker compose down (or docker stop ...)"
        fi
    fi

    local confirmar
    read -rp "Remove the Docker stack? Images and volumes are kept. [y/N]: " confirmar
    [[ "$confirmar" =~ ^[yYsS]$ ]] || { aviso "Cancelled."; exit 0; }

    sudo -v

    aviso "Stopping services..."
    # containerd viene como dependencia y su demonio queda corriendo por debajo de
    # dockerd; se baja explícito para no dejarlo huérfano hasta el reboot.
    sudo systemctl disable --now docker.service docker.socket 2> /dev/null || true
    sudo systemctl stop containerd.service 2> /dev/null || true

    if id -nG "$USER" | grep -qw docker; then
        sudo gpasswd -d "$USER" docker > /dev/null
        ok "$USER removed from the docker group."
    fi

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
        sudo pacman -Rns --noconfirm "${instalados[@]}"
    fi

    printf '\n'
    ok "Uninstalled. Your images, containers and volumes were kept:"
    aviso "  /var/lib/docker/   (everything docker ever stored)"
    aviso "  Delete it by hand if you want the disk space back: sudo rm -rf /var/lib/docker"
}

# ==========================================
# ENTRADA
# ==========================================
case "${1:-}" in
    install)   instalar ;;
    uninstall) desinstalar ;;
    status)    estado ;;
    "")
        printf '\n\033[1m=== Docker (engine + compose + buildx) ===\033[0m\n'
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
