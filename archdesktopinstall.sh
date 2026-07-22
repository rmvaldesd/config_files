#!/usr/bin/env bash

# Salir inmediatamente si un comando falla para evitar instalaciones parciales rotas
set -e

echo "=== Iniciando instalación del entorno Hyprland ==="

# ==========================================
# 1. ACTUALIZACIÓN Y HERRAMIENTAS BASE
# ==========================================
echo "-> Actualizando sistema e instalando herramientas base..."
sudo pacman -Syu --needed \
    base-devel \
    git \
    wget \
    curl

# ==========================================
# 2. INSTALACIÓN DE YAY (AUR HELPER)
# ==========================================
if ! command -v yay &> /dev/null; then
    echo "-> Instalando yay (AUR helper)..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    echo "-> yay se ha instalado correctamente."
else
    echo "-> yay ya está instalado en el sistema."
fi

# ==========================================
# 3. SOPORTE DE GRÁFICOS, AUDIO Y SISTEMA
# ==========================================
echo "-> Instalando controladores de video, audio y soporte XWayland..."
sudo pacman -S --needed \
    xorg-xwayland \    # Capa de compatibilidad para ejecutar aplicaciones nativas de X11 dentro de Wayland.
    pipewire \         # Servidor moderno de bajo nivel para gestionar audio y video.
    pipewire-alsa \    # Capa de compatibilidad para aplicaciones que usan el sistema ALSA antiguo.
    pipewire-pulse \   # Reemplazo de PulseAudio; permite que las apps que buscan PulseAudio funcionen con PipeWire.
    pipewire-jack \    # Soporte para audio profesional/baja latencia (JACK) a través de PipeWire.
    wireplumber \      # El gestor de sesiones para PipeWire; decide cómo se enrutan las entradas y salidas de audio.
    mesa \             # Controladores de código abierto para aceleración gráfica 3D (Intel/AMD).
    networkmanager \   # Demonio encargado de gestionar las conexiones a internet (Ethernet y Wi-Fi).
    bluez \            # Pila oficial del protocolo Bluetooth en Linux.
    bluez-utils        # Herramientas de línea de comandos para emparejar y gestionar dispositivos Bluetooth.

# ==========================================
# 4. NÚCLEO DEL ENTORNO DE ESCRITORIO
# ==========================================
echo "-> Instalando Hyprland, Ghostty, Waybar y herramientas principales..."
sudo pacman -S --needed \
    hyprland \                    # El compositor/gestor de ventanas principal basado en Wayland.
    waybar \                      # La barra de estado superior/inferior altamente configurable mediante CSS.
    ghostty \                     # Terminal moderna y ultrarrápida que utiliza aceleración por GPU.
    rofi \                        # Lanzador de aplicaciones y menús dinámicos (con soporte nativo para Wayland).
    firefox \                     # Navegador web principal.
    hyprlock \                    # Aplicación oficial de Hyprland para bloquear la pantalla de forma estética.
    hypridle \                    # Demonio que gestiona la inactividad del sistema (apagar pantalla, suspender, activar hyprlock).
    xdg-desktop-portal-hyprland \ # Permite compartir pantalla (en Meet/Discord) y comunicar apps con el compositor.
    qt6-wayland \                 # Añade soporte nativo de Wayland para aplicaciones desarrolladas en Qt6.
    qt5-wayland                   # Añade soporte nativo de Wayland para aplicaciones desarrolladas en Qt5.

# ==========================================
# 5. UTILIDADES DEL ECOSISTEMA Y PREFERENCIAS
# ==========================================
echo "-> Instalando utilidades complementarias..."
sudo pacman -S --needed \
    hyprpaper \       # Gestor oficial de fondos de pantalla para Hyprland (ligero y soporta múltiples monitores).
    mako \            # Servidor de notificaciones minimalista y ligero diseñado para Wayland.
    grim \            # Herramienta para tomar capturas de pantalla en Wayland.
    slurp \           # Permite seleccionar una región de la pantalla con el ratón (se usa en combinación con grim).
    wl-clipboard \    # Utilidad para gestionar el portapapeles (copiar/pegar) desde la terminal en Wayland.
    polkit-gnome \    # Agente de autenticación gráfica; levanta la ventana flotante para pedir tu clave sudo.
    thunar \          # Gestor de archivos gráfico y ligero del entorno XFCE.
    tumbler \         # Extensión para Thunar que permite generar miniaturas (thumbnails) de imágenes y videos.
    brightnessctl \   # Utilidad para controlar el brillo de la pantalla (ideal para laptops con teclas multimedia).
    pamixer           # Controlador de volumen por línea de comandos, excelente para enlazarlo a los atajos de teclado.

# ==========================================
# 6. FUENTES, TIPOGRAFÍAS Y APARIENCIA
# ==========================================
echo "-> Instalando fuentes tipográficas e iconos esenciales..."
sudo pacman -S --needed \
    ttf-font-awesome \          # Fuente de iconos muy utilizada por Waybar para mostrar el wifi, batería, volumen, etc.
    ttf-nerd-fonts-symbols \    # Glifos e iconos adicionales de la colección Nerd Fonts para desarrollo y terminal.
    ttf-jetbrains-mono-nerd \   # Tipografía monoespaciada ideal para programar y usar en la terminal Ghostty.
    papirus-icon-theme \        # Un paquete de iconos GTK moderno, limpio y muy popular en la comunidad.
    lxappearance                # Herramienta gráfica sencilla para cambiar el tema oscuro/claro, iconos y cursores GTK.

echo "---"
echo "=== ¡Instalación completada con éxito! ==="
echo "Tu sistema cuenta con yay instalado y listo para usar."
echo "Puedes iniciar tu entorno ejecutando: Hyprland"

exit 0

# ==============================================================================
#                 GUÍA DE CONFIGURACIÓN POST-INSTALACIÓN
# ==============================================================================
#
# Esta sección contiene apuntes clave para construir tus archivos de configuración
# dentro de '~/.config/'. Te servirá de mapa para entender cómo interactúan los paquetes.
#
# ------------------------------------------------------------------------------
# 1. ATAJOS MULTIMEDIA EN HYPRLAND (~/.config/hypr/hyprland.conf)
# ------------------------------------------------------------------------------
# Mapea las teclas físicas de brillo y volumen directamente a las utilidades instaladas:
#
#   # Control de Volumen (usando pamixer)
#   bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
#   bind = , XF86AudioLowerVolume, exec, pamixer -d 5
#   bind = , XF86AudioMute, exec, pamixer -t
#
#   # Control de Brillo de Pantalla (usando brightnessctl)
#   bind = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
#   bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
#
# ------------------------------------------------------------------------------
# 2. ATAJOS PARA CAPTURAS DE PANTALLA (~/.config/hypr/hyprland.conf)
# ------------------------------------------------------------------------------
# Grim y Slurp trabajan juntos. Slurp selecciona el área y Grim la captura.
# Wl-clipboard permite enviarla directo al portapapeles sin llenar tu disco de archivos.
#
#   # Capturar una región seleccionada al portapapeles:
#   bind = $mainMod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy
#
#   # Capturar pantalla completa y guardarla en una carpeta:
#   bind = $mainMod, Print, exec, grim ~/Imágenes/$(date +'%Y-%m-%d_%H-%m-%s').png
#
# ------------------------------------------------------------------------------
# 3. AUTOSTART DE DEMONIOS ESENCIALES (~/.config/hypr/hyprland.conf)
# ------------------------------------------------------------------------------
# Añade estas líneas al inicio de tu archivo de Hyprland para levantar el entorno base
# de forma automática en cada inicio de sesión:
#
#   exec-once = waybar                                # Inicia la barra de estado
#   exec-once = hyprpaper                             # Inicia el gestor de fondos de pantalla
#   exec-once = mako                                  # Inicia el servidor de notificaciones
#   exec-once = hypridle                              # Inicia el control de inactividad
#   exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 # Agente de contraseñas gráficas
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
# Tip: Utiliza las fuentes 'ttf-font-awesome' o 'ttf-jetbrains-mono-nerd' dentro de tu
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