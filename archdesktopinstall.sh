#!/usr/bin/env bash

# Salir inmediatamente si un comando falla para evitar instalaciones parciales rotas
set -e

# makepkg (usado para compilar yay) se niega a correr como root; ejecuta este script como tu usuario normal
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: No ejecutes este script como root/sudo. El script pedirá sudo solo cuando lo necesite."
    exit 1
fi

echo "=== Iniciando instalación del entorno Hyprland ==="

# --- Prechequeos: fallar a los segundos y con mensaje claro, no a los 10 minutos ---
# Van ANTES del bloque de sudo para no pedirte la contraseña sólo para dar un error.

# Requiere un sistema BOOTEADO: la sección 7 usa systemctl con --now, timedatectl y
# udevadm, que necesitan systemd corriendo como init. El check es el sd_booted() de
# systemd (/run/systemd/system existe sólo bajo systemd como PID 1). El caso
# arch-chroot igual lo bloquea el check de root de arriba: dentro de un chroot sos root.
if [ ! -d /run/systemd/system ]; then
    echo "ERROR: no hay systemd corriendo (¿chroot o contenedor?). Bootea la instalación"
    echo "       y ejecuta este script desde una TTY con tu usuario normal."
    exit 1
fi

# pacman con --noconfirm responde que NO a los prompts de eliminación de conflictos:
# si el equipo trae la pila de audio vieja (típico de un archinstall con perfil de
# audio), la sección 3 moriría con "unresolvable package conflicts" al instalar
# PipeWire, con el 80% del script sin correr. Mejor avisar acá con el comando exacto.
conflictivos=()
for paquete in pulseaudio pulseaudio-alsa pulseaudio-bluetooth jack2 pipewire-media-session; do
    pacman -Qq "$paquete" &>/dev/null && conflictivos+=("$paquete")
done
if [ "${#conflictivos[@]}" -gt 0 ]; then
    echo "ERROR: hay paquetes instalados que entran en conflicto con PipeWire/WirePlumber:"
    printf '         %s\n' "${conflictivos[@]}"
    echo "       Eliminálos y volvé a correr el script:"
    echo "         sudo pacman -Rns ${conflictivos[*]}"
    exit 1
fi

# El script está pensado para correr desatendido: pide la contraseña UNA vez acá y
# después no vuelve a interrumpir.
#
# Son dos mecanismos distintos y hacen falta los dos:
#   1. Este bloque, para la contraseña: 'sudo -v' la pide una vez y el bucle en
#      segundo plano refresca el timestamp cada 60s. Sin él, las descargas largas
#      superan el timeout de 5 minutos y sudo volvería a preguntar a mitad de proceso.
#      El trap mata el keepalive al salir, pase lo que pase.
#   2. El '--noconfirm' de cada pacman/yay/makepkg, para los prompts de los propios
#      instaladores ("Proceed with installation? [Y/n]"), que no tienen nada que ver
#      con sudo.
#
# Ojo con --noconfirm: toma la respuesta POR DEFECTO en todo, incluida la elección de
# proveedor cuando una dependencia tiene varios candidatos. En una instalación limpia
# con estos paquetes el default es el correcto, pero si algún día agregás algo con
# proveedores en conflicto, revisá esa parte a mano.
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
sudo pacman -Syu --needed --noconfirm "${paquetes_base[@]}"

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
    sof-firmware       # Firmware Sound Open Firmware; imprescindible para el audio de los portátiles Intel modernos.
    alsa-firmware      # Firmware adicional para tarjetas de sonido antiguas o específicas que lo requieren.
    alsa-ucm-conf      # Perfiles de configuración (Use Case Manager) que definen el enrutado correcto de altavoces y micrófonos.
    alsa-utils         # Herramientas de línea de comandos de ALSA (alsamixer, aplay, speaker-test) para diagnosticar el audio.
    linux-firmware     # Blobs de firmware para el kernel (Wi-Fi, gráficos, bluetooth y otros dispositivos).
    mesa               # Controladores de código abierto para aceleración gráfica 3D (Intel/AMD).
    networkmanager     # Demonio encargado de gestionar las conexiones a internet (Ethernet y Wi-Fi).
    bluez              # Pila oficial del protocolo Bluetooth en Linux.
    bluez-utils        # Herramientas de línea de comandos para emparejar y gestionar dispositivos Bluetooth.
)
sudo pacman -S --needed --noconfirm "${paquetes_sistema[@]}"

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
sudo pacman -S --needed --noconfirm "${paquetes_escritorio[@]}"

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
    imv               # Visor de imágenes nativo de Wayland, controlado por teclado (n/p para navegar, +/- zoom, q para salir). Es el habitual en setups de Hyprland/sway por ser mínimo. Queda como predeterminado para imágenes sin pasos extra: las asociaciones vienen dentro del mimeapps.list que enlaza la sección 9.
    zathura           # Visor de documentos minimalista con teclas tipo vim (j/k para desplazar, / para buscar, q para salir). Queda asociado a PDF vía mimeapps.list.
    zathura-pdf-poppler # OBLIGATORIO: zathura por sí solo NO abre ningún archivo, necesita un plugin de backend. Se elige poppler sobre mupdf porque este último arrastra tesseract con sus datos de OCR, innecesario para leer PDFs.
    mpv               # Reproductor de video y audio, nativo de Wayland y controlado por teclado (espacio pausa, flechas saltan, f pantalla completa, q sale). Queda asociado a los formatos de video vía mimeapps.list. Si alguna vez querés una interfaz gráfica, celluloid y haruna son frontends sobre este mismo motor.
    libreoffice-fresh # Suite ofimática. La variante 'fresh' trae las versiones nuevas; 'libreoffice-still' es la conservadora, si preferís estabilidad sobre funciones. No se instala el paquete de idioma (libreoffice-fresh-es) porque el locale de este equipo es en_US.
    gimp              # Editor de imágenes. NO se asocia a los tipos de imagen a propósito: esos abren con imv, que es el visor; solo .xcf (image/x-xcf) abre directo en GIMP, porque ningún visor lo lee. Para el resto, GIMP queda en el menú "Abrir con" de Thunar.
    obsidian          # Base de conocimiento sobre archivos Markdown locales.
    dbeaver           # Cliente SQL universal (Eclipse/SWT sobre GTK3). Corre en Wayland NATIVO sin tocar nada: no le pongas GDK_BACKEND=x11, que a escala 2x lo dejaría borroso. Ver docs/linux/dbeaver.md.
    jre21-openjdk     # Runtime de Java para dbeaver, que pide java-runtime>=21. Se fija el 21 (LTS) en vez del jre-openjdk suelto porque es la versión que DBeaver embebe en sus builds oficiales, o sea contra la que upstream realmente lo prueba. Es JRE y no JDK: sólo hace falta ejecutar, no compilar.
    brightnessctl     # Utilidad para controlar el brillo de la pantalla (ideal para laptops con teclas multimedia).
    power-profiles-daemon # Expone los perfiles performance/balanced/power-saver y los aplica al platform_profile ACPI y al EPP del intel_pstate. Waybar lo muestra con el módulo 'power-profiles-daemon'. NO instalar junto con tlp: se pisan entre sí.
    python-gobject    # Dependencia OPCIONAL de power-profiles-daemon pero obligatoria acá: sin ella 'powerprofilesctl' no arranca (ModuleNotFoundError: gi.repository) y power-profile-sync no puede cambiar el perfil.
    pamixer           # Controlador de volumen por línea de comandos, excelente para enlazarlo a los atajos de teclado.
    satty             # Herramienta moderna de anotación de capturas de pantalla (se usa con hyprshot en hyprland.lua).
    hyprshot          # Wrapper de grim+slurp para capturas de pantalla; usado en el bind de screenshot de hyprland.lua.
    bluetui           # TUI para gestionar dispositivos Bluetooth (on-click del módulo bluetooth en Waybar).
    playerctl         # Controla la reproducción multimedia (play/pause/next/prev) desde las teclas multimedia.
    wiremix           # Mezclador de audio en TUI (on-click del módulo de volumen en Waybar). Reemplaza a pavucontrol: cubre las mismas cinco pestañas -- incluida 'configuration', la de perfiles de tarjeta (A2DP/HSP, analógico/HDMI) que los mixers de terminal suelen no traer -- y habla PipeWire nativo en vez de pasar por la capa de compatibilidad PulseAudio.
    btop              # Monitor de recursos moderno en la terminal (on-click del módulo de CPU en Waybar).
    htop              # Monitor de procesos clásico en la terminal (on-click del módulo de memoria en Waybar).
    jq                # Procesador de JSON en la terminal; kb_layout.sh lo usa para leer la salida de 'hyprctl -j'.
    inotify-tools     # Provee 'inotifywait'; auto-reload.sh lo usa para recargar Waybar al guardar cambios en su config.
    psmisc            # Provee 'killall'; auto-reload.sh lo usa para enviar la señal SIGUSR2 de recarga a Waybar.
    neovim            # Editor de texto; su configuración se enlaza desde config_files/dotconfig/nvim en la sección 9.
    tmux              # Multiplexor de terminal; su configuración se enlaza desde config_files/tmux.conf en la sección 9.
    lazygit           # Interfaz TUI para git; simplifica staging, commits, ramas y rebases desde la terminal.
    fzf               # Buscador difuso (fuzzy finder) para la terminal; también lo usa el plugin fzf de nvim.
    glow              # Renderiza Markdown en la terminal (tablas alineadas, encabezados). Lo usa el atajo SUPER + A para mostrar docs/hyprland/README.md; sin él, ese atajo cae a 'less' y se ve el markdown crudo.
    ueberzugpp        # Dibuja imágenes dentro de la terminal. Lo usa la función 'imgs' de zshrc.local para previsualizar imágenes en fzf.
    ripgrep           # Grep ultrarrápido; Telescope de nvim lo necesita para live_grep.
    fd                # Alternativa moderna a find; Telescope de nvim lo usa para find_files.
    bat               # 'cat' con resaltado de sintaxis y numeración; lo usa el preview del widget Ctrl-G (grep en vivo) de zshrc.local. Si falta, ese preview cae a 'sed' sin resaltado.
    unzip             # Descompresor ZIP; Mason (nvim) lo necesita para extraer los LSPs que descarga.
    nodejs            # Runtime de JavaScript; requerido por varios LSPs que instala Mason (ts_ls, pyright, etc.).
    npm               # Gestor de paquetes de Node; Mason lo usa para instalar LSPs basados en Node.
    go                # Compilador de Go. Hace falta para 'nvim-dap-go' (debugging de Go) y porque el handler de gopls está DESHABILITADO a propósito en dotconfig/nvim/lua/plugins/init.lua, o sea que Mason no lo instala: gopls se pone a mano en la sección 14 y queda en ~/go/bin, que zshrc.local agrega al PATH. Lo mismo vale para cualquier binario de Go instalado así (templ, air, etc.).
    delve             # Debugger de Go; provee 'dlv', que es el backend que arranca 'nvim-dap-go' (dotconfig/nvim/lua/plugins/dap.lua). Viene de pacman y no de 'go install' porque está en los repos oficiales: así se actualiza con el resto del sistema en vez de quedar congelado en la versión que uno bajó a mano. Sin él, poner un breakpoint en un archivo .go falla al lanzar la sesión.
    python            # Intérprete de Python. Ya entra solo como dependencia de medio sistema (ufw, libreoffice, python-gobject...), pero se lista explícito por el mismo motivo que avahi: que en una instalación limpia quede marcado como instalado a propósito y no se lo lleve por delante un 'pacman -Rns' de alguno de esos paquetes. Ojo: eso vale para una instalación limpia. Si en el equipo ya estaba como dependencia, '--needed' lo saltea y NO le cambia la marca; para eso hay que correr 'pacman -D --asexplicit python' a mano.
    python-pip        # Provee el comando 'pip' fuera de un virtualenv. OJO con PEP 668: en Arch, tanto 'pip install' como 'pip install --user' fallan a propósito con "externally-managed-environment", para que pip no le pise archivos a pacman; hay que pasar --break-system-packages (desaconsejado) o usar un venv. Adentro de un venv NO hace falta este paquete: 'python -m venv' ya trae su propio pip vía ensurepip, que es el flujo que documenta dotconfig/nvim/GUIDE.md para debugpy.
    python-pipx       # Instala APLICACIONES de Python (no librerías) cada una en su propio virtualenv, y linkea el ejecutable en ~/.local/bin, que ya está en el PATH vía zshrc.local. Es la salida al PEP 668 de arriba para una herramienta de línea de comandos: 'pipx install diff-cover' anda donde 'pip install diff-cover' se niega. Antes de recurrir a pipx conviene buscar el paquete en los repos ('pacman -Ss python-<nombre>'): si está, ese se actualiza con el sistema. pipx queda para lo que no está empaquetado.
    tree-sitter-cli   # Compilador de parsers de Tree-sitter; nvim-treesitter lo necesita para instalar gramáticas.
    # --- Formateadores que declara conform.nvim (dotconfig/nvim/lua/plugins/format.lua) ---
    # Nadie los instalaba: mason-lspconfig sólo baja LSPs y no hay mason-tool-installer.
    # Como format_on_save usa lsp_format = "fallback", la falta no da error: simplemente
    # no se formatea, o se formatea distinto de lo declarado. El caso peor es Python,
    # donde pyright no formatea nada y el fallback no aporta.
    go-tools          # Provee 'goimports' (el paquete trae además stringer, callgraph, etc.). Es el primer formateador de Go en conform. gopls formatea igual vía el fallback LSP, pero eso NO agrega ni saca imports, que es justo lo que aporta goimports.
    gofumpt           # Segundo formateador de Go en conform. gopls lo trae embebido (gofumpt = true en lsp-settings.lua), pero conform invoca el BINARIO, así que hace falta igual.
    staticcheck       # Linter extra de Go, listado como prerequisito en dotconfig/nvim/GUIDE.md. Dentro de nvim no cambia nada -- gopls ya usa sus analizadores embebidos con staticcheck = true --; esto es para correrlo a mano desde la terminal.
    python-black      # Formateador de Python de conform. Sin él, guardar un .py no formatea NADA: pyright no tiene formateador, así que el fallback a LSP no cubre este caso.
    python-isort      # Ordena los imports de Python; corre antes que black en conform.
    stylua            # Formateador de Lua de conform (o sea, para editar esta misma config de nvim).
    prettier          # Formateador de conform para TS/JS/CSS/HTML/JSON/YAML/Markdown/GraphQL. En TS/JS el fallback a ts_ls tapa parte del hueco; en CSS, YAML y Markdown no hay nada detrás.
    # --- Herramientas de desarrollo ---
    man-db            # El comando 'man'. NO viene con base ni con base-devel: sin esto 'man ls' falla y uno se entera en el peor momento.
    man-pages         # Las páginas de manual de Linux propiamente dichas (secciones 2, 3, 7...). man-db es el lector; sin este paquete hay lector pero casi nada que leer.
    github-cli        # Provee 'gh': PRs, issues y reviews desde la terminal. Autenticar una vez con 'gh auth login'.
    direnv            # Carga y descarga variables de entorno al entrar y salir de un directorio (.envrc). Encaja con el flujo de virtualenv por proyecto que documenta GUIDE.md: un '.envrc' con 'layout python' activa el venv solo al hacer cd. OJO: sin el hook en la shell no hace absolutamente nada; ese hook está en zshrc.local.
    python-debugpy    # Debugger de Python. OJO: para que los breakpoints funcionen, debugpy tiene que estar en el MISMO intérprete que corre la app, o sea dentro del venv del proyecto ('python -m pip install debugpy' con el venv activado). Este paquete del sistema sólo cubre el camino de respaldo de dap.lua, cuando no hay venv y cae a 'python3'.
    python-pytest     # Corredor de tests de Python; dap.lua fija test_runner = "pytest". Aplica la misma advertencia que debugpy: en un proyecto con venv, el pytest que vale es el del venv.
    zsh               # Shell principal del usuario (se configura como shell por defecto en la sección 11).
    gvfs              # Capa de montaje virtual; permite a Thunar montar USBs, ver la papelera y unidades de red.
    gvfs-mtp          # Soporte MTP para gvfs; permite a Thunar acceder a celulares Android.
    xdg-user-dirs     # Crea los directorios estándar del usuario (~/Descargas, ~/Documentos, etc.).
    cliphist          # Historial del portapapeles para Wayland; sin él, lo copiado muere al cerrar la app de origen.
    cups              # Servidor de impresión. Arrastra cups-filters (los conversores que traducen el PDF que manda la app al formato que entiende la impresora).
    ghostscript       # Rasteriza el PDF a PWG-Raster/PCLm. Es sólo 'Optional Deps' de cups-filters ("for non-PDF printers"), así que pacman NO lo instala solo, pero hace falta para cualquier impresora que no acepte PDF nativo (la mayoría de las láser baratas: su 'pdl=' lista PCLm/urf pero no application/pdf). Sin él el fallo es silencioso y confuso: CUPS acepta el trabajo, lo encola y recién ahí muere con "universal filter failed".
    avahi             # Descubrimiento de servicios en la red local por mDNS/DNS-SD: es quien encuentra la impresora wifi sin que tengas que saber su IP. Ya viene como dependencia de cups, pero se lista explícito para que quede marcado como instalado a propósito y un futuro 'pacman -Rns cups' no se lo lleve.
    nss-mdns          # Enchufa avahi al resolvedor de nombres del sistema (ver el parche de nsswitch.conf en la sección 7). avahi por sí solo hace el DESCUBRIMIENTO, pero sin esto un 'ipp://IMPRESORA.local' no resuelve y la cola de impresión queda apuntando a un nombre muerto. Es lo que permite usar el hostname en vez de la IP, que el DHCP puede cambiar.
    system-config-printer # GUI para añadir y gestionar impresoras: Hyprland no trae panel de impresoras propio. La alternativa sin instalar nada es la interfaz web de CUPS en http://localhost:631.
    ufw               # Firewall sencillo; se activa en la sección 7 con política deny-incoming/allow-outgoing.
    spotify-launcher  # Descarga y mantiene actualizado el cliente oficial de Spotify desde el repositorio propio de Spotify.
)
sudo pacman -S --needed --noconfirm "${paquetes_utilidades[@]}"

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
sudo pacman -S --needed --noconfirm "${paquetes_apariencia[@]}"

# ==========================================
# 7. ACTIVACIÓN DE SERVICIOS DEL SISTEMA
# ==========================================
echo "-> Habilitando servicios del sistema..."
sudo systemctl enable NetworkManager.service         # Gestor de red al arrancar. Sin '--now' a propósito: si la conexión actual la maneja otro servicio (iwd, dhcpcd), arrancar NM aquí podría cortar la red a mitad del script.
sudo systemctl enable --now bluetooth.service        # Necesario para que bluez funcione y bluetui pueda gestionar dispositivos.
sudo systemctl enable ly@tty1.service                     # Pantalla de login TUI al arrancar. Sin '--now' a propósito: arrancarlo ahora tomaría la TTY en plena instalación.
sudo systemctl enable --now fstrim.timer             # TRIM semanal del SSD; mantiene el rendimiento del disco a largo plazo.
sudo systemctl enable --now ufw.service              # Arranca el firewall en cada boot.
sudo systemctl enable --now power-profiles-daemon.service  # Demonio de perfiles de energía. Sin 'enable' explícito sólo se activaría por D-Bus bajo demanda y no estaría listo al bootear.

# --- Impresión (avahi descubre la impresora en la red, cups la gestiona) ---
# systemd-resolved TAMBIÉN implementa mDNS y por defecto lo trae activado. Con los dos
# demonios respondiendo en el puerto 5353 el descubrimiento sale intermitente y ambos
# intentan publicar el mismo nombre .local. Se le apaga a resolved y se deja el mDNS en
# manos de avahi, que es el que CUPS consulta por D-Bus para listar impresoras.
sudo install -d /etc/systemd/resolved.conf.d
printf '[Resolve]\nMulticastDNS=no\n' | sudo tee /etc/systemd/resolved.conf.d/10-mdns-a-avahi.conf > /dev/null
# El restart va condicionado: en una instalación limpia resolved puede estar instalado
# pero sin arrancar, y un 'restart' a secas lo levantaría (cambiando el resolvedor DNS
# del sistema a mitad del script). Si no corre, el drop-in ya queda escrito para cuando arranque.
if systemctl is-active --quiet systemd-resolved.service; then
    sudo systemctl restart systemd-resolved.service
fi
# Con el mDNS de resolved apagado, los nombres .local dejan de resolver salvo que se
# enganche avahi al NSS. Este parche mete mdns_minimal al principio de la línea 'hosts:'
# de /etc/nsswitch.conf: sólo contesta nombres .local y para el resto devuelve UNAVAIL,
# así que el resto de la cadena (resolve, files, dns) sigue funcionando igual.
# El grep hace el paso idempotente: correr el script dos veces no duplica la entrada.
if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.bak.$(date +%Y%m%d%H%M%S)
    sudo sed -i -E 's/^(hosts:[[:space:]]*)/\1mdns_minimal [NOTFOUND=return] /' /etc/nsswitch.conf
    echo "-> nsswitch.conf: añadido mdns_minimal (respaldo con timestamp al lado)."
fi

sudo systemctl enable --now avahi-daemon.service     # Descubrimiento mDNS/DNS-SD; sin él la impresora wifi no aparece en la lista.
sudo systemctl enable --now cups.socket              # Se habilita el .socket y NO el .service a propósito: systemd levanta cupsd sólo cuando algo imprime o abre la GUI, en vez de tenerlo corriendo siempre.

sudo ufw allow 5353/udp comment 'mDNS: descubrimiento de impresoras y servicios en la LAN'  # La política deny-incoming descarta las respuestas mDNS (llegan como multicast, no como respuesta a una conexión saliente rastreada), así que sin esta regla la impresora nunca se descubre.
sudo ufw --force enable                              # Activa ufw con la política por defecto: bloquear entrante, permitir saliente.
sudo timedatectl set-ntp true                        # Sincronización de hora por NTP; un reloj desviado rompe TLS y las firmas de git/pacman.

# Servicios de audio: son de USUARIO (no del sistema), por eso van con 'systemctl --user' y sin sudo.
# PipeWire debe correr dentro de la sesión del usuario para tener acceso a su dispositivo de audio y a su dbus.
echo "-> Habilitando los servicios de audio de PipeWire para el usuario..."
if systemctl --user is-system-running &>/dev/null || [ -S "/run/user/$UID/bus" ]; then
    systemctl --user enable --now pipewire.service       # Servidor de audio/video principal.
    systemctl --user enable --now pipewire-pulse.service # Capa de compatibilidad con PulseAudio (navegadores, Discord, y todo lo que hable el protocolo de PulseAudio).
    systemctl --user enable --now wireplumber.service    # Gestor de sesiones; sin él PipeWire arranca pero no enruta ningún dispositivo.
else
    # Puede pasar si se corre desde una sesión sin gestor systemd --user (p. ej. un
    # 'su - usuario' sin login completo). El caso chroot ya lo cortan los prechequeos.
    echo "-> AVISO: no hay sesión de usuario systemd activa; no se pudieron habilitar los servicios de PipeWire."
    echo "   Ejecuta esto tras iniciar sesión: systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service"
fi

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
        # Ser un repo git no alcanza: si es OTRO repo que casualmente se llama igual,
        # saltarse el clonado haría morir las secciones 9-10 a mitad de camino (install
        # de archivos inexistentes), dejando la instalación parcial que set -e evita.
        remoto=$(git -C "$HOME/config_files" remote get-url origin 2>/dev/null || true)
        case "$remoto" in
            *rmvaldesd/config_files*)
                echo "-> ~/config_files ya existe y es el repo de dotfiles; se omite el clonado."
                ;;
            *)
                respaldo="$HOME/config_files.ajeno.$(date +%Y%m%d%H%M%S)"
                mv "$HOME/config_files" "$respaldo"
                echo "-> ~/config_files existía pero su remoto es '$remoto', no el repo de dotfiles; respaldado como $respaldo"
                clonar_dotfiles
                ;;
        esac
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
# El guard de existencia permite sumar o quitar directorios del repo sin tocar este
# script: los que no estén en dotconfig/ simplemente se saltean.
for dir in nvim hypr waybar rofi mako ghostty git; do
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

# Perfil de bloqueo de pantalla por defecto (hypridle).
#
# profiles/active.conf es un symlink al perfil elegido y NO está versionado (va en
# .gitignore): es estado de esta máquina, no configuración común. Por eso un clon
# recién bajado no lo trae y hay que crearlo acá.
#
# Sin él hypridle igual arranca seguro -- cae en los valores inline de hypridle.conf,
# que son los de oficina -- pero loguea un error de 'source= globbing' en cada inicio,
# y ese ruido taparía un error de config real más adelante. Mejor dejarlo explícito.
#
# Se elige OFFICE a propósito: ante la duda, el perfil más restrictivo (bloqueo a los
# 5 min en vez de 10). Cambiarlo después es 'hypridle-profile home'.
#
# El '-e' sigue el symlink, así que esto NO pisa una elección previa válida pero SÍ
# repone un enlace roto. Es idempotente: reejecutar el instalador no cambia tu perfil.
perfiles_hypr="$HOME/config_files/dotconfig/hypr/profiles"
if [ -d "$perfiles_hypr" ] && [ ! -e "$perfiles_hypr/active.conf" ]; then
    ln -sfn "office.conf" "$perfiles_hypr/active.conf"
    echo "-> Perfil de bloqueo inicial: office (cambialo con 'hypridle-profile home')"
fi

# Enlaza las asociaciones de archivos (qué app abre cada tipo de archivo).
# Va aparte del loop de arriba porque ese enlaza directorios y esto es un archivo suelto
# dentro de ~/.config. Verificado que 'xdg-mime default' y Thunar escriben A TRAVÉS del
# symlink en vez de reemplazarlo, así que los cambios que hagas desde la GUI quedan
# versionados solos.
if [ -e "$HOME/.config/mimeapps.list" ] && [ ! -L "$HOME/.config/mimeapps.list" ]; then
    respaldo="$HOME/.config/mimeapps.list.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.config/mimeapps.list" "$respaldo"
    echo "-> ~/.config/mimeapps.list ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/mimeapps.list" "$HOME/.config/mimeapps.list"
echo "-> Enlazado: ~/.config/mimeapps.list -> ~/config_files/mimeapps.list"

# Enlaza la config de spotify-launcher, que le pasa a Spotify los flags de Ozone
# para que arranque en Wayland nativo en vez de XWayland (si no, con el monitor a
# escala 2 se ve borroso). Otro archivo suelto en ~/.config, igual que el de arriba.
# El porqué está en docs/linux/spotify.md.
if [ -e "$HOME/.config/spotify-launcher.conf" ] && [ ! -L "$HOME/.config/spotify-launcher.conf" ]; then
    respaldo="$HOME/.config/spotify-launcher.conf.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.config/spotify-launcher.conf" "$respaldo"
    echo "-> ~/.config/spotify-launcher.conf ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/spotify-launcher.conf" "$HOME/.config/spotify-launcher.conf"
echo "-> Enlazado: ~/.config/spotify-launcher.conf -> ~/config_files/spotify-launcher.conf"

# Enlaza la config de teams-for-linux, que hace que la X CIERRE la app en vez de
# esconderla a la bandeja del sistema. Esta barra (waybar) no tiene módulo 'tray',
# así que sin esto la ventana se esconde a una bandeja que no existe: queda invisible
# y sin forma de recuperarla, con los procesos vivos. El porqué está en docs/linux/teams.md.
#
# Va enlazado archivo por archivo y NO como directorio, a diferencia del loop de más
# arriba: ~/.config/teams-for-linux es también el user-data-dir de Electron (Cache,
# Cookies, Session Storage). Enlazar el directorio completo al repo metería la sesión
# y los cachés adentro del control de versiones.
#
# El mkdir es necesario porque ese directorio recién existe después de la primera
# corrida de la app, y en un equipo nuevo el instalador va antes.
mkdir -p "$HOME/.config/teams-for-linux"
if [ -e "$HOME/.config/teams-for-linux/config.json" ] && [ ! -L "$HOME/.config/teams-for-linux/config.json" ]; then
    respaldo="$HOME/.config/teams-for-linux/config.json.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.config/teams-for-linux/config.json" "$respaldo"
    echo "-> config.json de teams-for-linux ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/teams-for-linux.config.json" "$HOME/.config/teams-for-linux/config.json"
echo "-> Enlazado: ~/.config/teams-for-linux/config.json -> ~/config_files/teams-for-linux.config.json"

# Enlaza el .desktop de teams-for-linux, que lo arranca en Wayland NATIVO. El del
# paquete trae '--ozone-platform=x11', y con eDP-1 a escala 2 XWayland se renderiza a
# 1x estirado a 2x: todo borroso. Mismo problema y misma clase de arreglo que Spotify
# (docs/linux/spotify.md); el porqué de este vive en docs/linux/teams.md.
#
# applications/ del repo mapea a ~/.local/share/applications, que tiene prioridad sobre
# /usr/share/applications cuando el archivo se llama igual. Así el override sobrevive a
# los upgrades del paquete, que reescriben el de /usr/share.
if [ -e "$HOME/.local/share/applications/teams-for-linux.desktop" ] && [ ! -L "$HOME/.local/share/applications/teams-for-linux.desktop" ]; then
    respaldo="$HOME/.local/share/applications/teams-for-linux.desktop.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.local/share/applications/teams-for-linux.desktop" "$respaldo"
    echo "-> El .desktop de teams-for-linux ya existía; respaldado como $respaldo"
fi
mkdir -p "$HOME/.local/share/applications"
ln -sfn "$HOME/config_files/applications/teams-for-linux.desktop" \
    "$HOME/.local/share/applications/teams-for-linux.desktop"
echo "-> Enlazado: ~/.local/share/applications/teams-for-linux.desktop -> ~/config_files/applications/teams-for-linux.desktop"

# El override es una copia COMPLETA del .desktop del paquete con una sola línea
# cambiada (el Exec), así que también congela los demás campos: Icon, StartupWMClass,
# el handler de x-scheme-handler/msteams y Categories. Si un upgrade de teams-for-linux
# cambia alguno de esos, nuestra copia lo pisaría en silencio y nadie se enteraría.
# Este chequeo compara todo MENOS el Exec (la línea que cambiamos a propósito) y avisa.
# El '!' delante del diff lo pone en contexto de condición, así que el 'set -e' de arriba
# no aborta el instalador cuando hay diferencias.
desktop_paquete="/usr/share/applications/teams-for-linux.desktop"
if [ -f "$desktop_paquete" ]; then
    if ! diff -q <(grep -v '^Exec=' "$desktop_paquete") \
                 <(grep -v '^Exec=' "$HOME/config_files/applications/teams-for-linux.desktop") > /dev/null; then
        echo "!! OJO: el .desktop del paquete teams-for-linux cambió más allá del Exec."
        echo "   Compará y actualizá nuestra copia:"
        echo "   diff $desktop_paquete ~/config_files/applications/teams-for-linux.desktop"
    fi
fi

# Refresca mimeinfo.cache para que quede registrado el handler de los links 'msteams:'
# (los 'Join meeting' de Outlook). Sin esto el .desktop igual sirve para el lanzador,
# pero xdg-open no sabría qué app abre ese esquema.
if command -v update-desktop-database > /dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
fi

# Enlaza la configuración de tmux directamente en el home
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    respaldo="$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.tmux.conf" "$respaldo"
    echo "-> ~/.tmux.conf ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/tmux.conf" "$HOME/.tmux.conf"
echo "-> Enlazado: ~/.tmux.conf -> ~/config_files/tmux.conf"

# Enlaza SÓLO las definiciones propias de zsh. ~/.zshrc no se versiona: lo genera
# oh-my-zsh desde su template en la sección 11, y ahí se le agrega el source de
# este archivo. Así las actualizaciones de oh-my-zsh no chocan con el repo.
if [ -e "$HOME/.zshrc.local" ] && [ ! -L "$HOME/.zshrc.local" ]; then
    respaldo="$HOME/.zshrc.local.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.zshrc.local" "$respaldo"
    echo "-> ~/.zshrc.local ya existía; respaldado como $respaldo"
fi
ln -sfn "$HOME/config_files/zshrc.local" "$HOME/.zshrc.local"
echo "-> Enlazado: ~/.zshrc.local -> ~/config_files/zshrc.local"

# Instala las fuentes versionadas en el repo (Symbols Nerd Font para los iconos de Waybar).
# Es el mismo script que se usa en Fedora, así ambas máquinas ven exactamente los mismos glifos.
bash "$HOME/config_files/scripts/install-fonts.sh"

# Enlaza en /usr/local/bin todo lo ejecutable de bin_configs/, que en el PATH precede a
# /usr/bin (por eso el wrapper 'dbeaver' logra tapar al binario del paquete). Hoy son:
#   hyprshutdown  menú de apagado, lo llama el bind SUPER+SHIFT+M
#   dbeaver       wrapper que le sube el heap de 1 GB a 4 GB (ver docs/linux/dbeaver.md)
#   add-printer   asistente de impresoras de red; la sección 7 deja la infraestructura
#                 lista pero no crea ninguna cola, porque eso depende de tu red
#   clean-orphans limpieza de paquetes huérfanos
#   pick-window   selector de ventanas del workspace actual, bind SUPER+W
#   find-file     busca un archivo en ~ y lo abre con su app por defecto, bind SUPER+F
#   hypridle-profile  cambia entre los perfiles de bloqueo home/office. El symlink del
#                 perfil activo lo dejó unas líneas más arriba esta misma sección, así
#                 que al terminar el instalador los perfiles quedan andando solos.
#
# Va como script aparte y en un loop, y no como cinco 'ln' acá, para que sumar un
# ejecutable a bin_configs/ no requiera acordarse de tocar este archivo. El script
# excluye power-profile-sync, que la sección 10 instala COPIADO y no enlazado.
bash "$HOME/config_files/scripts/link-bins.sh"

# ==========================================
# 10. CAMBIO AUTOMÁTICO DE PERFIL DE ENERGÍA
# ==========================================
# Va después de la sección 9 porque los archivos vienen del repo clonado en la 8.
#
# A diferencia de dotconfig/, estos archivos se COPIAN en vez de enlazarse:
#   - udev lee sus reglas antes de que se monte /home (que acá es el subvolumen
#     btrfs @home), así que un symlink a ~/config_files estaría roto justo en ese
#     momento y la regla no se cargaría nunca;
#   - la regla polkit y el script los consume root, y no deben vivir en una ruta
#     escribible por el usuario.
# Consecuencia: si editás estos archivos en el repo, hay que volver a correr esta
# sección para que el sistema los tome. Los 'install' son idempotentes.
echo "-> Configurando el cambio automático de perfil de energía..."

# Script que lee la fuente de alimentación y aplica el perfil que corresponde.
sudo install -Dm755 "$HOME/config_files/bin_configs/power-profile-sync" \
    /usr/local/bin/power-profile-sync

# Unit que ejecuta el script. Se dispara en tres momentos: al bootear
# (graphical.target), al despertar de la suspensión (suspend.target) y al
# conectar/desconectar el cargador (la regla udev de abajo).
sudo install -Dm644 "$HOME/config_files/etc/systemd/system/power-profile-sync.service" \
    /etc/systemd/system/power-profile-sync.service

# Regla udev: cualquier evento del cargador arranca la unit.
sudo install -Dm644 "$HOME/config_files/etc/udev/rules.d/99-power-profile-switch.rules" \
    /etc/udev/rules.d/99-power-profile-switch.rules

# Regla polkit: sin esto la unit recibe "denied". Corre como root pero sin sesión
# activa, y la política por defecto de switch-profile sólo permite allow_active.
sudo install -Dm644 "$HOME/config_files/etc/polkit-1/rules.d/49-power-profiles-root.rules" \
    /etc/polkit-1/rules.d/49-power-profiles-root.rules

sudo systemctl daemon-reload
sudo udevadm control --reload-rules

# 'enable' sólo crea los symlinks en graphical.target.wants y suspend.target.wants:
# es una operación de archivos que no falla. Va sin tolerancia a errores.
sudo systemctl enable power-profile-sync.service

# 'start' sí puede fallar (polkit todavía no releyó sus reglas, hardware sin perfiles,
# etc.) y con set -e eso abortaría la instalación entera dejando afuera oh-my-zsh, AUR
# y Claude Code. El perfil no es crítico y se corrige solo en el próximo boot o al
# mover el cargador, así que acá el error se tolera igual que en las secciones 12 y 13.
sudo systemctl start power-profile-sync.service || \
    echo "AVISO: no se pudo aplicar el perfil de energía ahora (se aplicará al reiniciar). Revisá con: systemctl status power-profile-sync.service"

# ==========================================
# 11. AJUSTES FINALES DE USUARIO
# ==========================================
echo "-> Aplicando ajustes finales..."
xdg-user-dirs-update                                 # Crea ~/Descargas, ~/Documentos, ~/Imágenes, etc. según el idioma del sistema.

# Instala oh-my-zsh (sólo el framework: se clona el repo, no se corre su instalador)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "-> Instalando oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

# ~/.zshrc queda como archivo REAL, no como symlink al repo: así oh-my-zsh (o su
# instalador oficial, si algún día lo corrés) puede actualizarlo sin pelearse con
# los dotfiles. Lo propio vive en ~/.zshrc.local, enlazado en la sección 9.
if [ -L "$HOME/.zshrc" ]; then
    # Viene del esquema anterior de este script, donde ~/.zshrc era symlink al repo.
    # No se pierde nada: lo propio ya está en zshrc.local.
    rm "$HOME/.zshrc"
    echo "-> ~/.zshrc era un symlink al repo (esquema viejo); se reemplaza por un archivo real."
fi
if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    echo "-> ~/.zshrc creado desde el template de oh-my-zsh."
fi

# Agrega el include una sola vez. Las comillas simples son a propósito: $HOME tiene
# que quedar literal en el archivo, no expandirse al escribirlo.
linea_include='[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
if ! grep -qF "$linea_include" "$HOME/.zshrc"; then
    printf '\n# Definiciones propias versionadas en ~/config_files/zshrc.local\n%s\n' "$linea_include" >> "$HOME/.zshrc"
    echo "-> Agregado a ~/.zshrc el source de ~/.zshrc.local."
fi
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo chsh -s /usr/bin/zsh "$USER"                # Deja zsh como shell por defecto del usuario.
    echo "-> Shell por defecto cambiado a zsh (aplica en el próximo login)."
fi

# ==========================================
# 12. PAQUETES DESDE AUR (VIA YAY)
# ==========================================
# Va al final a propósito: los builds de AUR se rompen con frecuencia y un fallo aquí no debe
# abortar el resto de la instalación (por eso además el error se tolera en vez de cortar con set -e).
# Nota: 'hyprshutdown' (invocado en hyprland.lua) no es un paquete instalable: es un script propio
# (bin_configs/hyprshutdown) que la sección 9 enlaza en /usr/local/bin.
# 'wpctl' viene incluido en wireplumber, 'gsettings' en glib2 y 'loginctl'/'systemctl' en systemd.
echo "-> Instalando paquetes desde AUR..."
paquetes_aur=(
    sublime-text-4   # Editor gráfico. No está en repos oficiales: el paquete de AUR descarga el binario oficial de sublimehq. Queda asociado a los archivos de texto y código vía mimeapps.list; neovim sigue siendo el editor de terminal.
)
yay -S --needed --noconfirm "${paquetes_aur[@]}" || \
    echo "AVISO: falló la instalación desde AUR; el resto del entorno quedó completo. Reintenta luego con: yay -S ${paquetes_aur[*]}"

# ==========================================
# 13. CLAUDE CODE
# ==========================================
# Instalador oficial de Anthropic; deja el binario en ~/.local/bin/claude (ya incluido en el PATH del zshrc).
# No viene de pacman ni de AUR, por eso va aparte y al final. curl ya se instaló en la sección 1.
# El error se tolera (igual que con AUR) para que un fallo de red aquí no aborte la instalación completa.
echo "-> Instalando Claude Code..."
if command -v claude &>/dev/null; then
    echo "-> Claude Code ya está instalado; se omite."
elif curl -fsSL https://claude.ai/install.sh | bash; then
    echo "-> Claude Code instalado. Ejecuta 'claude' tras reiniciar la shell para iniciar sesión."
else
    echo "AVISO: falló la instalación de Claude Code. Reintenta luego con: curl -fsSL https://claude.ai/install.sh | bash"
fi

# ==========================================
# 14. GOPLS (LSP DE GO)
# ==========================================
# El LSP de Go NO lo instala Mason: su handler está deshabilitado a propósito en
# dotconfig/nvim/lua/plugins/init.lua ('gopls = function() end'), así que hay que
# ponerlo a mano. 'go install' lo deja en ~/go/bin, que zshrc.local agrega al PATH.
#
# Va al final y con el error tolerado, igual que AUR y Claude Code: descarga de la
# red y un fallo acá no debe abortar una instalación que ya está completa.
#
# El guard mira la RUTA y no 'command -v gopls': en este punto del script la shell
# todavía no cargó el zshrc nuevo, así que ~/go/bin aún no está en el PATH y un
# 'command -v' fallaría siempre, reinstalando gopls en cada corrida.
#
# El debugger (delve/dlv) no va acá: viene de pacman en la sección 5.
echo "-> Instalando gopls (LSP de Go)..."
if [[ -x "$HOME/go/bin/gopls" ]]; then
    echo "-> gopls ya está instalado; se omite."
elif go install golang.org/x/tools/gopls@latest; then
    echo "-> gopls instalado en ~/go/bin/gopls."
else
    echo "AVISO: falló la instalación de gopls. Reintenta luego con: go install golang.org/x/tools/gopls@latest"
fi

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
#       on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'  # Apaga el monitor
#       on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'    # Lo enciende al mover el mouse
#   }
#
# Con la config de Hyprland en lua, 'hyprctl dispatch dpms off' NO funciona (se
# interpreta como codigo lua) y el campo se llama 'action', no 'state': con una clave
# desconocida el dispatcher cae a TOGGLE y termina apagando en vez de encender. Las dos
# fallas devuelven exit 0, asi que no avisan. Detalle completo en hypridle.conf.
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
# ------------------------------------------------------------------------------
# 8. PERFILES DE ENERGÍA (ya configurados en la sección 10)
# ------------------------------------------------------------------------------
# El perfil cambia solo: 'performance' enchufado, 'balanced' en batería. Lo decide
# /usr/local/bin/power-profile-sync leyendo /sys/class/power_supply/A*/online.
#
# Para ver el estado y cambiarlo a mano:
#   powerprofilesctl get / list / set balanced
#   systemctl start power-profile-sync.service   # vuelve a sincronizar con el cargador
#
# Un cambio manual (por ejemplo con el click en el módulo de Waybar) dura hasta el
# próximo evento de cargador, boot o resume; ahí se resincroniza.
#
# Para cambiar qué perfil corresponde a cada estado, editá el if de
# bin_configs/power-profile-sync y volvé a correr la sección 10.
#
# ------------------------------------------------------------------------------
# 9. IMPRESIÓN WIFI (paquetes en la sección 5, servicios en la sección 7)
# ------------------------------------------------------------------------------
# Para añadir la impresora: ejecutá 'system-config-printer' y entrá en "Añadir".
# Debería aparecer sola bajo "Impresoras de red". La otra vía es http://localhost:631.
#
# NO se instala ningún driver a propósito: cualquier impresora de los últimos años
# soporta IPP Everywhere / AirPrint, o sea que CUPS habla con ella sin driver. Sólo
# si la tuya es vieja o imprime mal hace falta uno, y depende de la marca:
#   HP      -> hplip                          (repos oficiales)
#   Epson   -> epson-inkjet-printer-escpr     (repos oficiales)
#   Brother -> yay -S brother-<modelo>        (AUR, buscá tu modelo exacto)
#   Canon / genéricas -> gutenprint + foomatic-db
#
# El usuario NO necesita estar en ningún grupo extra: cups-files.conf de Arch trae
# 'SystemGroup sys root wheel' y este usuario ya está en wheel (sale del instalador
# de Arch). El grupo 'lp' sólo hace falta para impresoras USB conectadas directo.
#
# Diagnóstico cuando la impresora no aparece:
#   avahi-browse -rt _ipp._tcp          # ¿la ve la red? Si sale vacío, es avahi/firewall
#   systemctl status avahi-daemon cups  # ¿están corriendo los dos?
#   sudo ufw status | grep 5353         # ¿está la regla de mDNS?
#   resolvectl mdns                     # debe decir 'no' en todos lados (lo apaga la sección 7)
#   lpstat -p -d                        # impresoras ya configuradas y cuál es la predeterminada
#
# Documentación ampliada: docs/linux/impresion.md
#
