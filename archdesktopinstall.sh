#!/usr/bin/env bash

# Salir inmediatamente si un comando falla para evitar instalaciones parciales rotas
set -e

# makepkg (usado para compilar yay) se niega a correr como root; ejecuta este script como tu usuario normal
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: No ejecutes este script como root/sudo. El script pedirá sudo solo cuando lo necesite."
    exit 1
fi

echo "=== Iniciando instalación del entorno Hyprland ==="

# Pide la contraseña de sudo una sola vez y la mantiene viva durante todo el script
# (las descargas largas superan el timeout de 5 minutos y sudo volvería a preguntar a mitad de proceso)
sudo -v
( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ==========================================
# 0. LLAVERO DE FIRMAS (KEYRING)
# ==========================================
# Si se instala desde una ISO con meses de antigüedad, las llaves de firma quedan obsoletas y
# pacman falla con errores de "invalid or corrupted package"; actualizar el llavero primero lo evita.
echo "-> Actualizando el llavero de firmas de Arch..."
sudo pacman -Sy --noconfirm archlinux-keyring

# ==========================================
# 1. ACTUALIZACIÓN Y HERRAMIENTAS BASE
# ==========================================
echo "-> Actualizando sistema e instalando herramientas base..."
paquetes_base=(
    base-devel        # Grupo de herramientas de compilación (gcc, make, etc.); requerido para construir paquetes AUR.
    git               # Sistema de control de versiones; necesario para clonar yay y tus dotfiles.
    wget              # Descarga de archivos por línea de comandos.
    curl              # Transferencia de datos por URL; requerido por muchos scripts e instaladores.
)
sudo pacman -Syu --needed "${paquetes_base[@]}"

# ==========================================
# 2. INSTALACIÓN DE YAY (AUR HELPER)
# ==========================================
if ! command -v yay &> /dev/null; then
    echo "-> Instalando yay (AUR helper)..."
    rm -rf /tmp/yay   # Limpia restos de una ejecución anterior fallida para que el clone no falle
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd - > /dev/null
    echo "-> yay se ha instalado correctamente."
else
    echo "-> yay ya está instalado en el sistema."
fi

# ==========================================
# 3. SOPORTE DE GRÁFICOS, AUDIO Y SISTEMA
# ==========================================
echo "-> Instalando controladores de video, audio y soporte XWayland..."
paquetes_sistema=(
    xorg-xwayland      # Capa de compatibilidad para ejecutar aplicaciones nativas de X11 dentro de Wayland.
    pipewire           # Servidor moderno de bajo nivel para gestionar audio y video.
    pipewire-alsa      # Capa de compatibilidad para aplicaciones que usan el sistema ALSA antiguo.
    pipewire-pulse     # Reemplazo de PulseAudio; permite que las apps que buscan PulseAudio funcionen con PipeWire.
    pipewire-jack      # Soporte para audio profesional/baja latencia (JACK) a través de PipeWire.
    wireplumber        # El gestor de sesiones para PipeWire; decide cómo se enrutan las entradas y salidas de audio.
    mesa               # Controladores de código abierto para aceleración gráfica 3D (Intel/AMD).
    networkmanager     # Demonio encargado de gestionar las conexiones a internet (Ethernet y Wi-Fi).
    bluez              # Pila oficial del protocolo Bluetooth en Linux.
    bluez-utils        # Herramientas de línea de comandos para emparejar y gestionar dispositivos Bluetooth.
)
sudo pacman -S --needed "${paquetes_sistema[@]}"

# ==========================================
# 4. NÚCLEO DEL ENTORNO DE ESCRITORIO
# ==========================================
echo "-> Instalando Hyprland, Ghostty, Waybar y herramientas principales..."
paquetes_escritorio=(
    hyprland                      # El compositor/gestor de ventanas principal basado en Wayland.
    waybar                        # La barra de estado superior/inferior altamente configurable mediante CSS.
    ghostty                       # Terminal moderna y ultrarrápida que utiliza aceleración por GPU.
    rofi                          # Lanzador de aplicaciones y menús dinámicos (con soporte nativo para Wayland).
    firefox                       # Navegador web principal.
    chromium                      # Navegador secundario; Waybar lo usa para abrir Google Calendar en modo app (on-click del reloj).
    hyprlock                      # Aplicación oficial de Hyprland para bloquear la pantalla de forma estética.
    hypridle                      # Demonio que gestiona la inactividad del sistema (apagar pantalla, suspender, activar hyprlock).
    xdg-desktop-portal-hyprland   # Permite compartir pantalla (en Meet/Discord) y comunicar apps con el compositor.
    xdg-desktop-portal-gtk        # Complementa al portal de Hyprland: provee el diálogo de abrir/guardar archivos que ese no implementa.
    qt6-wayland                   # Añade soporte nativo de Wayland para aplicaciones desarrolladas en Qt6.
    qt5-wayland                   # Añade soporte nativo de Wayland para aplicaciones desarrolladas en Qt5.
    ly                            # Display manager minimalista en TUI; pantalla de login que lanza la sesión de Hyprland.
)
sudo pacman -S --needed "${paquetes_escritorio[@]}"

# ==========================================
# 5. UTILIDADES DEL ECOSISTEMA Y PREFERENCIAS
# ==========================================
echo "-> Instalando utilidades complementarias..."
paquetes_utilidades=(
    hyprpaper         # Gestor oficial de fondos de pantalla para Hyprland (ligero y soporta múltiples monitores).
    mako              # Servidor de notificaciones minimalista y ligero diseñado para Wayland.
    grim              # Herramienta para tomar capturas de pantalla en Wayland.
    slurp             # Permite seleccionar una región de la pantalla con el ratón (se usa en combinación con grim).
    wl-clipboard      # Utilidad para gestionar el portapapeles (copiar/pegar) desde la terminal en Wayland.
    polkit-gnome      # Agente de autenticación gráfica; levanta la ventana flotante para pedir tu clave sudo.
    thunar            # Gestor de archivos gráfico y ligero del entorno XFCE.
    tumbler           # Extensión para Thunar que permite generar miniaturas (thumbnails) de imágenes y videos.
    brightnessctl     # Utilidad para controlar el brillo de la pantalla (ideal para laptops con teclas multimedia).
    pamixer           # Controlador de volumen por línea de comandos, excelente para enlazarlo a los atajos de teclado.
    satty             # Herramienta moderna de anotación de capturas de pantalla (se usa con hyprshot en hyprland.lua).
    hyprshot          # Wrapper de grim+slurp para capturas de pantalla; usado en el bind de screenshot de hyprland.lua.
    bluetui           # TUI para gestionar dispositivos Bluetooth (on-click del módulo bluetooth en Waybar).
    playerctl         # Controla la reproducción multimedia (play/pause/next/prev) desde las teclas multimedia.
    pavucontrol       # Mezclador de audio gráfico para PulseAudio/PipeWire (on-click del módulo de volumen en Waybar).
    btop              # Monitor de recursos moderno en la terminal (on-click del módulo de CPU en Waybar).
    htop              # Monitor de procesos clásico en la terminal (on-click del módulo de memoria en Waybar).
    jq                # Procesador de JSON en la terminal; kb_layout.sh lo usa para leer la salida de 'hyprctl -j'.
    inotify-tools     # Provee 'inotifywait'; auto-reload.sh lo usa para recargar Waybar al guardar cambios en su config.
    psmisc            # Provee 'killall'; auto-reload.sh lo usa para enviar la señal SIGUSR2 de recarga a Waybar.
    neovim            # Editor de texto; su configuración se enlaza desde config_files/dotconfig/nvim en la sección 10.
    tmux              # Multiplexor de terminal; su configuración se enlaza desde config_files/tmux.conf en la sección 10.
    lazygit           # Interfaz TUI para git; simplifica staging, commits, ramas y rebases desde la terminal.
    fzf               # Buscador difuso (fuzzy finder) para la terminal; también lo usa el plugin fzf de nvim.
    ripgrep           # Grep ultrarrápido; Telescope de nvim lo necesita para live_grep.
    fd                # Alternativa moderna a find; Telescope de nvim lo usa para find_files.
    unzip             # Descompresor ZIP; Mason (nvim) lo necesita para extraer los LSPs que descarga.
    nodejs            # Runtime de JavaScript; requerido por varios LSPs que instala Mason (ts_ls, pyright, etc.).
    npm               # Gestor de paquetes de Node; Mason lo usa para instalar LSPs basados en Node.
    zsh               # Shell principal del usuario (se configura como shell por defecto en la sección 11).
    gvfs              # Capa de montaje virtual; permite a Thunar montar USBs, ver la papelera y unidades de red.
    gvfs-mtp          # Soporte MTP para gvfs; permite a Thunar acceder a celulares Android.
    xdg-user-dirs     # Crea los directorios estándar del usuario (~/Descargas, ~/Documentos, etc.).
    cliphist          # Historial del portapapeles para Wayland; sin él, lo copiado muere al cerrar la app de origen.
    ufw               # Firewall sencillo; se activa en la sección 7 con política deny-incoming/allow-outgoing.
)
sudo pacman -S --needed "${paquetes_utilidades[@]}"

# ==========================================
# 6. FUENTES, TIPOGRAFÍAS Y APARIENCIA
# ==========================================
echo "-> Instalando fuentes tipográficas e iconos esenciales..."
paquetes_apariencia=(
    otf-font-awesome            # Fuente de iconos muy utilizada por Waybar para mostrar el wifi, batería, volumen, etc.
    ttf-nerd-fonts-symbols      # Glifos e iconos adicionales de la colección Nerd Fonts para desarrollo y terminal.
    ttf-jetbrains-mono-nerd     # Tipografía monoespaciada ideal para programar y usar en la terminal Ghostty.
    ttf-jetbrains-mono          # Provee la familia exacta "JetBrains Mono" que piden hyprlock.conf y waybar/style.css (la Nerd registra otro nombre; en Fedora esa familia ya existe).
    papirus-icon-theme          # Un paquete de iconos GTK moderno, limpio y muy popular en la comunidad.
    adw-gtk-theme               # Tema GTK3 'adw-gtk3-dark' que hyprland.lua activa vía gsettings en el autostart.
    lxappearance                # Herramienta gráfica sencilla para cambiar el tema oscuro/claro, iconos y cursores GTK.
)
sudo pacman -S --needed "${paquetes_apariencia[@]}"

# ==========================================
# 7. ACTIVACIÓN DE SERVICIOS DEL SISTEMA
# ==========================================
echo "-> Habilitando servicios del sistema..."
sudo systemctl enable NetworkManager.service         # Gestor de red al arrancar. Sin '--now' a propósito: si la conexión actual la maneja otro servicio (iwd, dhcpcd), arrancar NM aquí podría cortar la red a mitad del script.
sudo systemctl enable --now bluetooth.service        # Necesario para que bluez funcione y bluetui pueda gestionar dispositivos.
sudo systemctl enable ly.service                     # Pantalla de login TUI al arrancar. Sin '--now' a propósito: arrancarlo ahora tomaría la TTY en plena instalación.
sudo systemctl enable --now fstrim.timer             # TRIM semanal del SSD; mantiene el rendimiento del disco a largo plazo.
sudo systemctl enable --now ufw.service              # Arranca el firewall en cada boot.
sudo ufw --force enable                              # Activa ufw con la política por defecto: bloquear entrante, permitir saliente.
sudo timedatectl set-ntp true                        # Sincronización de hora por NTP; un reloj desviado rompe TLS y las firmas de git/pacman.

# ==========================================
# 8. CLONADO DE DOTFILES (config_files)
# ==========================================
echo "-> Clonando el repositorio de dotfiles en ~/config_files..."
clonar_dotfiles() {
    # accept-new: acepta el fingerprint de GitHub en la primera conexión sin el prompt interactivo yes/no.
    # Intenta por SSH (requiere que tu llave esté cargada en GitHub); si falla, cae a HTTPS de solo lectura.
    if ! GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone git@github.com:rmvaldesd/config_files.git "$HOME/config_files"; then
        echo "-> Clonado por SSH falló (¿llave SSH sin configurar?). Intentando por HTTPS..."
        git clone https://github.com/rmvaldesd/config_files.git "$HOME/config_files"
        echo "-> AVISO: quedó clonado por HTTPS. Para poder hacer push, configura tu llave SSH y ejecuta:"
        echo "          git -C ~/config_files remote set-url origin git@github.com:rmvaldesd/config_files.git"
    fi
}

if [ -d "$HOME/config_files" ]; then
    if git -C "$HOME/config_files" rev-parse --git-dir > /dev/null 2>&1; then
        echo "-> ~/config_files ya existe y es un repositorio git válido; se omite el clonado."
    else
        # Un clone anterior que quedó a medias dejaría los symlinks apuntando a contenido incompleto
        respaldo="$HOME/config_files.corrupto.$(date +%Y%m%d%H%M%S)"
        mv "$HOME/config_files" "$respaldo"
        echo "-> ~/config_files existía pero no era un repositorio git válido; respaldado como $respaldo"
        clonar_dotfiles
    fi
else
    clonar_dotfiles
fi

# ==========================================
# 9. ENLACES SIMBÓLICOS DE CONFIGURACIÓN
# ==========================================
echo "-> Creando enlaces simbólicos de los dotfiles..."
mkdir -p "$HOME/.config"

# Enlaza cada directorio de config_files/dotconfig dentro de ~/.config.
# mako y ghostty aún no están versionados: el guard de existencia permite agregarlos al repo
# más adelante sin tocar este script.
for dir in nvim hypr waybar rofi mako ghostty; do
    origen="$HOME/config_files/dotconfig/$dir"
    [ -d "$origen" ] || continue
    destino="$HOME/.config/$dir"
    # Si ya existe una config real (no un symlink), se respalda con timestamp para no perder nada
    # ni corromper respaldos previos (mv sobre un .bak existente lo anidaría adentro)
    if [ -e "$destino" ] && [ ! -L "$destino" ]; then
        respaldo="${destino}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$destino" "$respaldo"
        echo "-> $destino ya existía; respaldado como $respaldo"
    fi
    ln -sfn "$origen" "$destino"
    echo "-> Enlazado: $destino -> ~/config_files/dotconfig/$dir"
done

# Enlaza la configuración de tmux directamente en el home
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    respaldo="$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.tmux.conf" "$respaldo"
    echo "-> ~/.tmux.conf ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/tmux.conf" "$HOME/.tmux.conf"
echo "-> Enlazado: ~/.tmux.conf -> ~/config_files/tmux.conf"

# Enlaza la configuración de zsh en el home
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    respaldo="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.zshrc" "$respaldo"
    echo "-> ~/.zshrc ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/zshrc" "$HOME/.zshrc"
echo "-> Enlazado: ~/.zshrc -> ~/config_files/zshrc"

# Instala las fuentes versionadas en el repo (Symbols Nerd Font para los iconos de Waybar).
# Es el mismo script que se usa en Fedora, así ambas máquinas ven exactamente los mismos glifos.
bash "$HOME/config_files/scripts/install-fonts.sh"

# Enlaza hyprshutdown (menú de apagado con rofi) en el PATH del sistema para que el bind SUPER+SHIFT+M lo encuentre
sudo ln -sfn "$HOME/config_files/bin_configs/hyprshutdown" /usr/local/bin/hyprshutdown
echo "-> Enlazado: /usr/local/bin/hyprshutdown -> ~/config_files/bin_configs/hyprshutdown"

# ==========================================
# 10. AJUSTES FINALES DE USUARIO
# ==========================================
echo "-> Aplicando ajustes finales..."
xdg-user-dirs-update                                 # Crea ~/Descargas, ~/Documentos, ~/Imágenes, etc. según el idioma del sistema.

# Instala oh-my-zsh (solo el framework; el ~/.zshrc versionado ya quedó enlazado en la sección 10)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "-> Instalando oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo chsh -s /usr/bin/zsh "$USER"                # Deja zsh como shell por defecto del usuario.
    echo "-> Shell por defecto cambiado a zsh (aplica en el próximo login)."
fi

# ==========================================
# 11. PAQUETES DESDE AUR (VIA YAY)
# ==========================================
# Va al final a propósito: los builds de AUR se rompen con frecuencia y un fallo aquí no debe
# abortar el resto de la instalación (por eso además el error se tolera en vez de cortar con set -e).
# Nota: 'hyprshutdown' (invocado en hyprland.lua) no es un paquete instalable: es un script propio
# (bin_configs/hyprshutdown) que la sección 9 enlaza en /usr/local/bin.
# 'wpctl' viene incluido en wireplumber, 'gsettings' en glib2 y 'loginctl'/'systemctl' en systemd.
echo "-> Instalando paquetes desde AUR..."
paquetes_aur=(
    nmrs              # GUI Wayland-nativa para NetworkManager (on-click del módulo network en Waybar). Solo existe en AUR.
)
yay -S --needed --noconfirm "${paquetes_aur[@]}" || \
    echo "AVISO: falló la instalación desde AUR; el resto del entorno quedó completo. Reintenta luego con: yay -S ${paquetes_aur[*]}"

echo "---"
echo "=== ¡Instalación completada con éxito! ==="
echo "Tu sistema cuenta con yay instalado y listo para usar."
echo "Reinicia el equipo: ly te mostrará la pantalla de login y ahí seleccionas la sesión de Hyprland."
echo "(También puedes iniciarlo sin reiniciar ejecutando: Hyprland)"

exit 0

# ==============================================================================
#                 GUÍA DE CONFIGURACIÓN POST-INSTALACIÓN
# ==============================================================================
#
# Esta sección contiene apuntes clave para construir tus archivos de configuración
# dentro de '~/.config/'. Te servirá de mapa para entender cómo interactúan los paquetes.
#
# ------------------------------------------------------------------------------
# 1. ATAJOS MULTIMEDIA (ya configurados en dotconfig/hypr/hyprland.lua)
# ------------------------------------------------------------------------------
# Volumen y micrófono con wpctl (WirePlumber), brillo con brightnessctl y control de
# reproducción con playerctl — todo mapeado a las teclas XF86 en hyprland.lua.
# pamixer queda instalado como alternativa por línea de comandos: pamixer -i 5 / -d 5 / -t
#
# ------------------------------------------------------------------------------
# 2. CAPTURAS DE PANTALLA (ya configuradas en hyprland.lua)
# ------------------------------------------------------------------------------
# La tecla Print captura una región con hyprshot y la abre en satty para anotar/guardar.
# grim y slurp quedan instalados como alternativa de bajo nivel:
#   grim -g "$(slurp)" - | wl-copy      # región directa al portapapeles
#
# ------------------------------------------------------------------------------
# 3. AUTOSTART (ya configurado en hyprland.lua)
# ------------------------------------------------------------------------------
# El bloque hl.on("hyprland.start") ya lanza: ghostty, hyprpaper, waybar, auto-reload.sh,
# hypridle, mako, el agente polkit-gnome y el watcher de cliphist.
# Si agregas un demonio nuevo al entorno, recuerda sumarlo ahí.
#
# ------------------------------------------------------------------------------
# 4. LANZADOR DE APLICACIONES (~/.config/hypr/hyprland.conf y rofi)
# ------------------------------------------------------------------------------
# Para lanzar Rofi en modo Wayland con una combinación de teclas (ej: Super + Espacio):
#
#   bind = $mainMod, space, exec, rofi -show drun -show-icons
#
# Nota: La configuración visual de rofi se genera con el comando 'rofi -dump-config > ~/.config/rofi/config.rasi'
#
# ------------------------------------------------------------------------------
# 5. GESTIÓN DE INACTIVIDAD Y BLOQUEO (~/.config/hypr/hypridle.conf)
# ------------------------------------------------------------------------------
# Hypridle controla el tiempo. Un archivo básico en '~/.config/hypr/hypridle.conf' luce así:
#
#   listener {
#       timeout = 300                                 # 5 minutos
#       on-timeout = hyprlock                         # Comando para bloquear pantalla
#   }
#   listener {
#       timeout = 600                                 # 10 minutos
#       on-timeout = hyprctl dispatch dpms off        # Apaga el monitor de forma nativa
#       on-resume = hyprctl dispatch dpms on          # Enciende el monitor al mover el mouse
#   }
#
# ------------------------------------------------------------------------------
# 6. ESTILEADO DE LA BARRA (~/.config/waybar/)
# ------------------------------------------------------------------------------
# Waybar requiere dos archivos obligatorios en '~/.config/waybar/':
#   - 'config': Define la estructura en JSON (módulos a la izquierda, centro y derecha).
#   - 'style.css': Controla los colores, bordes y espaciados usando código CSS estándar.
#
# Tip: Utiliza las fuentes 'otf-font-awesome' o 'ttf-jetbrains-mono-nerd' dentro de tu
# archivo JSON para renderizar iconos nativos en módulos como batería (), wifi () o volumen ().
#
# ------------------------------------------------------------------------------
# 7. TEMAS OSCUROS Y ESTÉTICA GTK (lxappearance)
# ------------------------------------------------------------------------------
# Dado que no tienes un entorno de escritorio completo (como GNOME o KDE) que maneje
# las preferencias visuales de las aplicaciones, ejecuta 'lxappearance' desde tu terminal
# o rofi. Te permitirá seleccionar de forma global el tema oscuro, cursores y paquetes
# de iconos (como Papirus) para que aplicaciones como Firefox y Thunar no se vean blancas
# o con estilos viejos.
#