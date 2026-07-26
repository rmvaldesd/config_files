#!/usr/bin/env bash
# Instala o desinstala el entorno de virtualización: QEMU/KVM + libvirt + virt-manager.
#
# Vive en extras/ porque NO es parte del entorno base que arma archdesktopinstall.sh:
# se corre a mano en las máquinas donde haga falta virtualizar.
#
#   ./virtualization.sh install     # instala todo, habilita el servicio y la red NAT
#   ./virtualization.sh uninstall   # da de baja todo; los discos de las VMs se conservan
#   ./virtualization.sh status      # qué hay instalado y en qué estado
#   ./virtualization.sh             # menú interactivo con esas tres opciones
#
# Los comentarios van en español como el resto del repo; los mensajes en inglés.

set -euo pipefail

morir()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
aviso()  { printf '\033[33m->\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m->\033[0m %s\n' "$*"; }

# usermod/gpasswd necesitan un usuario real; correrlo como root además dejaría a
# root (y no a vos) en el grupo libvirt. Mismo criterio que archdesktopinstall.sh.
[ "$EUID" -eq 0 ] && morir "do not run this as root/sudo; it will ask for sudo when needed."

# 'qemu' a secas ya no existe: Arch lo partió en subpaquetes en 2022. El equivalente
# de aquel paquete gordo es qemu-full; acá se instalan las dos mitades que interesan
# por separado, para que quede dicho qué aporta cada una.
PAQUETES=(
    qemu-desktop         # Emulación de sistema x86_64 con todo lo de escritorio: UI GTK/SDL, audio por PipeWire, video virtio/QXL, SPICE y redirección USB.
    qemu-emulators-full  # Emuladores de TODAS las demás arquitecturas (ARM, RISC-V, PowerPC...), modo sistema y modo usuario. Sin esto sólo se virtualiza x86_64.
    qemu-img             # Crear/convertir/inspeccionar imágenes de disco. Se lista explícito porque qemu-desktop NO lo garantiza como dependencia, y virt-manager lo usa al crear discos.
    libvirt              # El demonio (libvirtd) y la API que orquesta QEMU: define VMs, redes y almacenamiento. virt-manager es sólo un cliente de esto.
    virt-manager         # GUI para crear y administrar las VMs.
    virt-viewer          # Visor SPICE/VNC liviano para conectarse a la pantalla de una VM sin abrir virt-manager entero.
    dnsmasq              # DHCP y DNS de la red NAT 'default' de libvirt; sin él las VMs no obtienen IP.
    edk2-ovmf            # Firmware UEFI para las VMs. Necesario para instalar Windows 11 y para cualquier guest que no quiera BIOS legacy.
    swtpm                # TPM 2.0 emulado. Windows 11 lo exige; los guests Linux no lo necesitan.
    dmidecode            # libvirt lo usa para leer/inyectar datos SMBIOS del host en los guests.
    virtiofsd            # Compartir carpetas host<->guest (virtiofs). Es paquete SEPARADO desde que lo sacaron de qemu; sin él, virt-manager ofrece el filesystem passthrough igual y la VM falla al arrancar con un error confuso.
)

# ==========================================
# ESTADO
# ==========================================
estado() {
    printf '\n\033[1m=== Virtualization stack status ===\033[0m\n\n'

    printf '%-22s %s\n' "PACKAGE" "INSTALLED"
    local p v
    for p in "${PAQUETES[@]}"; do
        v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}') || true
        printf '%-22s %s\n' "$p" "${v:--}"
    done

    printf '\n'
    # KVM: sin el flag de CPU o sin /dev/kvm las VMs corren por software (TCG), o
    # sea inutilizablemente lentas. Casi siempre es VT-x deshabilitado en la BIOS.
    if grep -qEm1 'vmx|svm' /proc/cpuinfo && [ -e /dev/kvm ]; then
        ok "KVM: available (/dev/kvm present, CPU flag $(grep -oEm1 'vmx|svm' /proc/cpuinfo))"
    else
        aviso "KVM: NOT available - VMs would run on slow software emulation. Check that VT-x/AMD-V is enabled in the BIOS."
    fi

    # is-active imprime el estado ('inactive', 'active'...) TAMBIÉN cuando falla o la
    # unit no existe, así que se toma su salida y sólo se cae al placeholder si vino vacía.
    local srv modo
    srv=$(systemctl is-active libvirtd.service 2>/dev/null || true)
    # Qué se habilitó decide el modo: el .socket habilitado (con el .service no)
    # significa arranque bajo demanda.
    if [ "$(systemctl is-enabled libvirtd.service 2>/dev/null || true)" = "enabled" ]; then
        modo="at boot (libvirtd.service)"
    elif [ "$(systemctl is-enabled libvirtd.socket 2>/dev/null || true)" = "enabled" ]; then
        modo="on demand (libvirtd.socket)"
    else
        modo="not enabled"
    fi
    printf 'libvirtd service : %s\n' "${srv:-not-found}"
    printf 'start mode       : %s\n' "$modo"
    if id -nG "$USER" | grep -qw libvirt; then
        printf 'libvirt group    : %s is a member\n' "$USER"
    else
        printf 'libvirt group    : %s is NOT a member (virt-manager will ask for the root password)\n' "$USER"
    fi

    # Sólo consulta libvirt si hay con qué y con permisos; un status nunca debe pedir password.
    if command -v virsh > /dev/null && systemctl is-active --quiet libvirtd.service && id -nG "$USER" | grep -qw libvirt; then
        printf '\nNetworks:\n'; virsh --connect qemu:///system net-list --all 2>/dev/null || true
        printf 'VMs:\n';        virsh --connect qemu:///system list --all 2>/dev/null || true
    fi
    printf '\n'
}

# ==========================================
# INSTALAR
# ==========================================
instalar() {
    # Avisar ANTES de instalar: sin KVM todo funciona igual, pero la experiencia es
    # tan mala que probablemente lo que uno quiere es ir a la BIOS primero.
    if ! grep -qEm1 'vmx|svm' /proc/cpuinfo; then
        aviso "WARNING: no vmx/svm CPU flag. VMs will run on software emulation (very slow)."
        aviso "Enable VT-x / AMD-V in the BIOS before creating VMs."
    fi

    sudo -v

    aviso "Installing packages..."
    sudo pacman -S --needed --noconfirm "${PAQUETES[@]}"

    # Se usa el demonio monolítico (libvirtd) y no los modulares (virtqemud & cía):
    # para un equipo de escritorio es la vía simple y la que documenta la wiki para
    # virt-manager. virtlogd y virtlockd los arrastra la propia unit.
    #
    # Dos modos de arranque, con un tradeoff que decide el usuario:
    #
    #   .service : libvirtd corre desde el boot. Las VMs marcadas con autostart
    #              arrancan solas. Costo medido en este equipo: ~32 MB de RAM y
    #              ~1.5s de arranque, permanentes, más los dos dnsmasq de la red NAT.
    #
    #   .socket  : systemd escucha /run/libvirt/libvirt-sock SIN el demonio y lo
    #              arranca al primer cliente (virt-manager, virsh). A cambio, las
    #              VMs con autostart NO arrancan solas tras un reboot, y la red NAT
    #              no se levanta hasta el primer uso.
    #
    # Ojo: el socket arranca bajo demanda pero NO apaga al quedar ocioso; una vez
    # levantado sigue vivo hasta el próximo reboot.
    printf '\n'
    aviso "Start mode:"
    printf '  1) At boot (libvirtd.service) - VMs marked autostart come back after a reboot\n'
    printf '  2) On demand (libvirtd.socket) - daemon starts on first use; no VM autostart\n\n'
    local modo
    read -rp "Choice [1]: " modo || true
    if [ "${modo:-1}" = "2" ]; then
        aviso "Enabling libvirtd.socket (on demand)..."
        # El disable del .service es por si se corre install de nuevo para cambiar
        # de modo: sin esto quedarían los dos habilitados y ganaría el del boot.
        sudo systemctl disable --now libvirtd.service 2> /dev/null || true
        # El enable del .socket arrastra los -ro y -admin por su Also=.
        sudo systemctl enable --now libvirtd.socket
    else
        aviso "Enabling libvirtd.service (at boot)..."
        sudo systemctl enable --now libvirtd.service
    fi

    # El grupo libvirt da acceso a qemu:///system sin password (regla polkit que
    # trae el propio paquete). Sin esto, virt-manager pide la clave de root en cada uso.
    if id -nG "$USER" | grep -qw libvirt; then
        ok "$USER already in the libvirt group."
    else
        sudo usermod -aG libvirt "$USER"
        ok "$USER added to the libvirt group. LOG OUT AND BACK IN for it to take effect."
    fi

    # La red NAT 'default' viene definida por libvirt pero apagada y sin autostart.
    # Sin ella las VMs nacen sin conectividad. El net-start se tolera si ya está activa.
    #
    # 'autostart' acá significa "cuando libvirtd corra, levantá esta red", así que
    # respeta el modo elegido arriba: con el socket, la red (y sus dos dnsmasq) no
    # existen hasta el primer uso. Estos virsh sí despiertan al demonio ahora mismo,
    # porque hay que hablarle para configurarlo; a partir del próximo boot manda el modo.
    aviso "Enabling the default NAT network..."
    sudo virsh net-autostart default > /dev/null
    sudo virsh net-start default 2> /dev/null || true

    printf '\n'
    ok "Done. Open 'virt-manager' to create a VM (log out first if the group was just added)."
    printf '\n'
    # Los dos "peros" que el host no puede resolver y conviene saber ANTES de crear la VM:
    # el ISO de drivers para guests Windows no está empaquetado en los repos oficiales,
    # y los agentes de integración se instalan DENTRO del guest, no acá.
    aviso "Windows guests: the installer ships no virtio drivers, so it won't see the disk."
    aviso "  Grab the virtio-win ISO (Fedora project / AUR) and attach it as a second CD-ROM."
    aviso "Inside Linux guests, install: spice-vdagent (shared clipboard, auto-resize)"
    aviso "  and qemu-guest-agent (clean shutdown from virt-manager)."
    printf '\n'
    # ufw antepone DROP al forwarding; libvirt mete sus propias cadenas LIBVIRT_FWI/FWO
    # al frente así que en general convive bien, pero es EL sospechoso si un guest no navega.
    aviso "Note: this machine runs ufw. libvirt inserts its own forward rules and normally"
    aviso "coexists fine, but if a guest has no network, that interaction is the first suspect."
}

# ==========================================
# DESINSTALAR
# ==========================================
desinstalar() {
    # Con VMs corriendo, bajar libvirtd las mata sin apagado limpio. Mejor negarse.
    if command -v virsh > /dev/null && systemctl is-active --quiet libvirtd.service; then
        local activas
        activas=$(sudo virsh list --name 2>/dev/null | grep -c . || true)
        if [ "${activas:-0}" -gt 0 ]; then
            sudo virsh list 2>/dev/null || true
            morir "there are running VMs. Shut them down first: sudo virsh shutdown <name>"
        fi
    fi

    local confirmar
    read -rp "Remove the virtualization stack? Disk images are kept. [y/N]: " confirmar
    [[ "$confirmar" =~ ^[yYsS]$ ]] || { aviso "Cancelled."; exit 0; }

    sudo -v

    aviso "Stopping services..."
    sudo systemctl disable --now libvirtd.service 2> /dev/null || true
    # virtlogd y virtlockd no se 'enable'aron explícitamente: los arrastra libvirtd
    # (Requires=/Wants= al arrancar, Also= en el enable). El disable de arriba los
    # saca del boot, pero su --now sólo detiene a libvirtd; estos quedan corriendo
    # hasta el reboot si no se paran acá.
    sudo systemctl stop virtlogd.service virtlogd.socket virtlogd-admin.socket \
        virtlockd.service virtlockd.socket virtlockd-admin.socket 2> /dev/null || true

    if id -nG "$USER" | grep -qw libvirt; then
        sudo gpasswd -d "$USER" libvirt > /dev/null
        ok "$USER removed from the libvirt group."
    fi

    # Se desinstala sólo lo que esté presente: correr uninstall dos veces, o tras una
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
    ok "Uninstalled. Your VM disks and configs were kept:"
    aviso "  /var/lib/libvirt/   (disk images)  |  /etc/libvirt/ leftovers, if any"
    aviso "  Delete them by hand if you want a clean slate: sudo rm -rf /var/lib/libvirt /etc/libvirt"
}

# ==========================================
# ENTRADA
# ==========================================
case "${1:-}" in
    install)   instalar ;;
    uninstall) desinstalar ;;
    status)    estado ;;
    "")
        printf '\n\033[1m=== Virtualization (QEMU/KVM + libvirt + virt-manager) ===\033[0m\n'
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
