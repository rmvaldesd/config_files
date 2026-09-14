#!/usr/bin/env bash
# Dictado por voz push-to-talk (voxtype): daemon + OSD + backend de tipeo (wtype).
#
# Instala lo MISMO en Arch y en Fedora (los dos los maneja este repo; archdesktopinstall.sh
# lleva la parte Arch de esto ya incluida también):
#   - Arch: voxtype-bin del AUR en prebuilt + wtype de los repos.
#   - Fedora: el .rpm oficial de GitHub Releases (Fedora 40+/glibc 2.39+ en adelante) + wtype.
#
# Vive en extras/ porque NO es parte del entorno base: se corre a mano, sólo en las
# máquinas donde se use dictado. La activación por compositor (bind SUPER+T -> 'voxtype
# record toggle' en hyprland.lua) y el módulo de forma en Waybar (custom/voxtype en
# dotconfig/waybar) vienen del repo de dotfiles compartido y a este script no le tocan:
# acá es sólo el software, el modelo y el servicio.
#
#   ./voxtype/voxtype.sh install     # instala el stack, baja el modelo y deja el daemon arriba
#   ./voxtype/voxtype.sh uninstall   # da de baja el stack (no toca tu config ni el modelo)
#   ./voxtype/voxtype.sh status      # estado del paquete, daemon, modelo y backend activo
#   ./voxtype/voxtype.sh             # menú interactivo con esas tres opciones
#
# Los comentarios van en español como el resto del repo; los mensajes en inglés.

set -euo pipefail

morir()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
aviso()  { printf '\033[33m->\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m->\033[0m %s\n' "$*"; }

# Igual que el resto de extras/: nada de correr como root, se pide sudo puntualmente.
[ "$EUID" -eq 0 ] && morir "do not run this as root/sudo; it will ask for sudo when needed."

# ==========================================
# DETECCIÓN DE DISTRO
# ==========================================
DISTRO=""
if [ -f /etc/arch-release ]; then
    DISTRO="arch"
elif [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
else
    morir "unsupported distro; this script knows Arch Linux and Fedora."
fi

# La versión se saca SOLA de la última release de GitHub: no hay que tocarla a mano cuando
# sale una actualización. Esta constante es solo el respaldo si la API no responde.
FALLBACK_VERSION="1.0.1"

version_latest() {
    local asset
    asset=$(curl -fsSL "https://api.github.com/repos/peteonrails/voxtype/releases/latest" \
                2>/dev/null | grep -oE 'voxtype-[0-9]+\.[0-9]+\.[0-9]+-1\.x86_64\.rpm' | head -1) \
        || true
    if [ -n "$asset" ]; then
        printf '%s' "$asset"
    else
        printf 'voxtype-%s-1.x86_64.rpm' "$FALLBACK_VERSION"
    fi
}

RPM_ASSET=""

# ==========================================
# HELPERS DE COMPROBACIÓN
# ==========================================
# El .rpm oficial pide glibc 2.39+ (Fedora 40 o más nueva en adelante). ldd imprime su
# versión en la primera línea: "ldd (GNU libc) 2.42".
glibc_mayor()  { ldd --version 2>/dev/null | sed -n '1s/.* //p' | sed 's/\..*//'; }
glibc_menor()  { ldd --version 2>/dev/null | sed -n '1s/.* //p' | sed 's/.*\.//'; }
glibc_ok() {
    local may men
    may=$(glibc_mayor) men=$(glibc_menor)
    [ "$may" -gt 2 ] || { [ "$may" -eq 2 ] && [ "$men" -ge 39 ]; }
}

# ==========================================
# ESTADO
# ==========================================
estado() {
    printf '\n\033[1m=== Voxtype (voice-to-text) status ===\033[0m\n\n'

    case "$DISTRO" in
        arch)
            printf '%-18s %s\n' "PACKAGE" "VERSION"
            local p v
            for p in voxtype-bin wtype; do
                v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}') || true
                printf '%-18s %s\n' "$p" "${v:--}"
            done
            ;;
        fedora)
            printf '%-16s %s\n' "PACKAGE" "VERSION"
            for p in voxtype wtype wl-clipboard; do
                v=$(rpm -q --qf '%{VERSION}' "$p" 2>/dev/null) || true
                printf '%-16s %s\n' "$p" "${v:--}"
            done
            ;;
    esac

    printf '\n%-12s %s\n' "SERVICE" "state (enabled / active)"
    local enac act
    enac=$(systemctl --user is-enabled voxtype.service 2>/dev/null) || enac="-"
    act=$(systemctl --user is-active voxtype.service 2>/dev/null) || act="-"
    printf '%-12s %s / %s\n' "voxtype" "$enac" "$act"

    printf '\n'
    # El modelo y la config del usuario son lo que de verdad importa para el daemon.
    if command -v voxtype > /dev/null; then
        if [ -s "$HOME/.local/share/voxtype/models/ggml-base.en.bin" ]; then
            ls -lh "$HOME/.local/share/voxtype/models/ggml-base.en.bin" \
                | awk '{printf "%-12s %s (%s)\n", "MODEL", $9, $5}'
        else
            aviso "Model file not downloaded yet (run 'install')."
        fi
        local cfg
        cfg="$HOME/.config/voxtype/config.toml"
        if [ -f "$cfg" ]; then
            local modelo hotkey
            modelo=$(sed -n 's/^model = "\(.*\)"/\1/p' "$cfg") || true
            hotkey=$(sed -n 's/^enabled = \(.*\)$/\1/p' "$cfg" | head -1) || true
            printf '%-12s model = %s | hotkey.enabled = %s\n' "CONFIG" "${modelo:-(unset)}" "${hotkey:-(unset)}"
        else
            aviso "No config file at $cfg; 'install' creates it."
        fi
        printf '\n'
        voxtype setup gpu --status 2>&1 || true
    else
        aviso "voxtype is not installed."
    fi
    printf '\n'
}

# ==========================================
# CONFIG Y POST-INSTALACIÓN (común a las dos distros)
# ==========================================
# Lo que hace que el daemon sirva, sin importar de qué paquete vino:
#   1. servicio de USUARIO habilitado + arrancado (igual que los de PipeWire).
#   2. modelo Whisper descargado. 'setup --download' es idempotente: si ya está lo
#      confirma, si no lo baja (~141 MB hacia ~/.local/share/voxtype/models).
#   3. model = "base.en" en la config del usuario. La config que voxtype genera de cero
#      trae 'model = "base"', y como acá se baja sólo la variante base.en, si quedara
#      'base' el daemon crashea con "Model 'base' not found". 'voxtype config set' no
#      acepta la clave 'model' (ver 'voxtype config schema'), así que va sed directo;
#      si ya dice base.en el sed no toca nada.
#   4. hotkey interno desactivado: la activación la maneja el bind del compositor
#      (Hyprland: SUPER+T -> 'voxtype record toggle'), no la tecla del propio voxtype.
post_instalacion() {
    sudo -v
    aviso "Enabling the user service..."
    # enable --now arranca el daemon; el restart del final reaplica la config ya corregida.
    systemctl --user enable --now voxtype.service

    aviso "Downloading the Whisper model (base.en) if needed..."
    voxtype setup --download --model base.en --no-post-install

    sed -i 's/^model = "base"$/model = "base.en"/' "$HOME/.config/voxtype/config.toml"

    aviso "Disabling the built-in hotkey (the compositor bind does the activation)..."
    voxtype config set hotkey.enabled false

    aviso "Restarting the daemon with the corrected config..."
    systemctl --user restart voxtype.service

    printf '\n'
    ok "Done. The daemon is running and will come back on login (user service, enabled)."
    aviso "Activate it from the compositor bind: SUPER+T -> 'voxtype record toggle'"
    aviso "The Waybar module (custom/voxtype) comes from the shared dotfiles; reload waybar to show it."
}

# ==========================================
# INSTALAR (según distro)
# ==========================================
instalar() {
    sudo -v

    case "$DISTRO" in
        arch)
            command -v yay > /dev/null || \
                morir "yay (AUR helper) not found; install it first (archdesktopinstall.sh does it) and re-run."
            aviso "Installing voxtype-bin from the AUR and wtype..."
            yay -S --needed --noconfirm voxtype-bin
            sudo pacman -S --needed --noconfirm wtype
            ;;
        fedora)
            if ! glibc_ok; then
                morir "the official voxtype .rpm needs glibc 2.39+ (Fedora 40 or newer); this system has ldd $(ldd --version 2>/dev/null | sed -n '1s/.* //p'). Upgrade or build from source (docs/INSTALL.md)."
            fi
            RPM_ASSET="$(version_latest)"
            aviso "Installing typing & clipboard backends (wtype, wl-clipboard)..."
            sudo dnf install -y wtype wl-clipboard
            aviso "Downloading and installing the official .rpm ($RPM_ASSET)..."
            # GitHub desactivó la ruta 'releases/latest/download/<archivo>': hay que ir a la
            # URL anclada al tag (v<versión>). De ahí: base = https://.../releases/download/v1.0.1
            local tmp rpm base
            tmp=$(mktemp -d)
            rpm="${tmp}/${RPM_ASSET}"
            base="https://github.com/peteonrails/voxtype/releases/download/v${RPM_ASSET#voxtype-}"
            base="${base%-1.x86_64.rpm}"
            curl -fL "${base}/${RPM_ASSET}" -o "$rpm"
            curl -fL "${base}/SHA256SUMS.txt" -o "${tmp}/SHA256SUMS.txt"
            ( cd "$tmp" && tr -d '\r' < SHA256SUMS.txt | grep -F "  ${RPM_ASSET}" | sha256sum -c - ) || \
                { rm -rf "$tmp"; morir "checksum mismatch for $RPM_ASSET; refusing to install. Check the release assets and the script version."; }
            sudo dnf install -y "$rpm"
            rm -rf "$tmp"
            ;;
    esac

    printf '\n'
    post_instalacion
}

# ==========================================
# DESINSTALAR
# ==========================================
desinstalar() {
    # Por convención de extras/: borra el stack pero NUNCA la config del usuario
    # (~/.config/voxtype) ni el modelo (~/.local/share/voxtype); al final avisa dónde
    # quedan y cómo limpiarlos a mano.
    local confirmar
    read -rp "Remove the voxtype stack? (config and models stay) [y/N]: " confirmar
    [[ "$confirmar" =~ ^[yYsS]$ ]] || { aviso "Cancelled."; exit 0; }

    sudo -v
    systemctl --user disable --now voxtype.service 2> /dev/null || true

    case "$DISTRO" in
        arch)
            local instalados=() p
            for p in voxtype-bin wtype; do
                pacman -Qq "$p" &> /dev/null && instalados+=("$p")
            done
            if [ "${#instalados[@]}" -eq 0 ]; then
                aviso "No voxtype packages are installed; nothing to remove."
            else
                aviso "Removing: ${instalados[*]}"
                # -Rns arrastra las dependencias que queden huérfanas; wtype suele ser
                # dependencia opcional de nadie, así que sale solo.
                yay -Rns --noconfirm "${instalados[@]}"
            fi
            ;;
        fedora)
            if rpm -q voxtype &> /dev/null; then
                aviso "Removing voxtype..."
                sudo dnf remove -y voxtype
            else
                aviso "voxtype is not installed."
            fi
            # wtype/wl-clipboard se dejan: un usuario seguramente los usa fuera del dictado.
            ;;
    esac

    printf '\n'
    ok "Uninstalled."
    aviso "Config (hotkey, model) stays at:"
    aviso "  ~/.config/voxtype/config.toml"
    aviso "  ~/.local/share/voxtype/models/   (model files)"
    aviso "Remove them by hand if you will not use voxtype anymore."
}

# ==========================================
# ENTRADA
# ==========================================
case "${1:-}" in
    install)   instalar ;;
    uninstall) desinstalar ;;
    status)    estado ;;
    "")
        printf '\n\033[1m=== Voxtype (voice-to-text) ===\033[0m\n'
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