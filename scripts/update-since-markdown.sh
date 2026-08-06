#!/usr/bin/env bash
# Pone al día un equipo que se instaló ANTES de que los .md pasaran a abrirse con
# glow en vez de con Sublime Text.
#
# Son TRES piezas y las tres tienen que estar, si no la asociación queda a medias:
#
#   mimeapps.list      -> la línea 'text/markdown=glow.desktop'. Viaja sola con el
#                         'git pull': ~/.config/mimeapps.list es un symlink al del
#                         repo. Esta es la única pieza que no hace falta tocar acá.
#   glow.desktop       -> el paquete glow NO trae ninguno (es un binario de terminal
#                         a secas), así que hay que enlazar el nuestro desde
#                         applications/. Sin él, mimeapps.list apunta a un .desktop
#                         que no existe y el sistema cae al siguiente handler.
#   perl-file-mimeinfo -> sólo para el 'xdg-open' de la TERMINAL. Ver la sección 3.
#
# Síntomas de que un equipo necesita esto:
#   - Doble clic en un .md desde Thunar lo abre en Sublime Text.
#   - 'xdg-open notas.md' desde la terminal abre Sublime Text.
#
# El primer síntoma lo arreglan las dos primeras piezas; el segundo necesita
# además la tercera, y es habitual quedarse a mitad de camino: se arregla Thunar,
# se prueba desde la terminal, y parece que no funcionó nada.
#
# Uso:
#   bash ~/config_files/scripts/update-since-markdown.sh
#
# Es idempotente: reejecutarlo en un equipo ya al día no cambia nada, y ni
# siquiera pide sudo si no falta ningún paquete.

set -e

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: No ejecutes este script como root/sudo. Pedirá sudo sólo cuando lo necesite."
    exit 1
fi

REPO="$HOME/config_files"
if [ ! -d "$REPO/.git" ]; then
    echo "ERROR: no existe $REPO (o no es un repo git). Cloná primero:"
    echo "       git clone git@github.com:rmvaldesd/config_files.git $REPO"
    exit 1
fi

# ==========================================
# 1. ACTUALIZAR EL REPO
# ==========================================
# --ff-only a propósito: si el equipo tiene commits locales propios que
# divergieron, mejor que el script se detenga acá y lo resuelva a mano en vez
# de mezclar historias solo.
echo "-> Actualizando $REPO..."
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "AVISO: $REPO tiene cambios sin commitear; se omite 'git pull' para no pisarlos."
    echo "       Revisá con 'git -C $REPO status' y corré 'git -C $REPO pull' a mano."
else
    git -C "$REPO" pull --ff-only
fi

# ==========================================
# 2. LA ASOCIACIÓN LLEGA POR EL SYMLINK
# ==========================================
# mimeapps.list no se copia: ~/.config/mimeapps.list tiene que ser un symlink al
# del repo (lo arma la sección 9 del instalador). Si en este equipo es un archivo
# de verdad, el 'git pull' de arriba no lo tocó y el resto del script va a dejar
# todo listo para una asociación que nunca se va a leer. Mejor avisar fuerte.
mimeapps="$HOME/.config/mimeapps.list"
if [ -L "$mimeapps" ]; then
    echo "-> mimeapps.list: OK, es un symlink al repo."
elif [ -e "$mimeapps" ]; then
    echo "!! OJO: $mimeapps es un archivo propio, NO un symlink al repo."
    echo "   La línea 'text/markdown=glow.desktop' no llegó con el pull. Compará y"
    echo "   reemplazalo por el enlace:"
    echo "   diff $mimeapps $REPO/mimeapps.list"
    echo "   ln -sfn $REPO/mimeapps.list $mimeapps"
else
    echo "-> mimeapps.list no existe; se crea el symlink al del repo."
    mkdir -p "$HOME/.config"
    ln -sfn "$REPO/mimeapps.list" "$mimeapps"
fi

# ==========================================
# 3. PAQUETES
# ==========================================
# glow ya estaba en la lista del instalador desde antes (lo usa el atajo SUPER + A),
# pero se chequea igual: es gratis y el equipo podría venir de más atrás.
#
# perl-file-mimeinfo es el que de verdad falta, y sólo arregla el camino de la
# TERMINAL. Sin él, 'xdg-open archivo.md' abre Sublime aunque mimeapps.list diga
# glow: bajo Hyprland, xdg-mime no reconoce el entorno y cae a su rama genérica,
# que detecta el tipo con 'file --mime-type'. Y 'file' mira el CONTENIDO, así que
# un .md le da text/plain, o sea el handler de text/plain, que es Sublime.
#
# Thunar y 'gio' nunca pasan por ahí: usan GLib, que resuelve por EXTENSIÓN, y
# '*.md' pesa 50 para text/markdown contra 10 de dos globs de ROMs de Sega Genesis
# que comparten la extensión. Por eso desde Thunar funciona sin este paquete.
#
# 'mimetype' (que es lo que aporta perl-file-mimeinfo) resuelve por glob igual que
# GLib, y la rama genérica de xdg-mime lo prefiere sobre 'file' si existe. Alinea
# los dos caminos para TODOS los tipos, no sólo markdown: cualquier formato que
# sea texto por dentro (.json, .yaml, .lua, .go...) tenía el mismo problema.
paquetes_markdown=(
    glow
    perl-file-mimeinfo
)

# Se calcula lo que falta ANTES de llamar a pacman, en vez de tirarle la lista
# entera con --needed. Con --needed pacman igual no reinstala nada, pero sudo
# pide la clave igual: el script te interrumpiría para no hacer nada. Así, en un
# equipo ya al día, esto termina en silencio.
faltantes=()
for p in "${paquetes_markdown[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || faltantes+=("$p")
done

if [ ${#faltantes[@]} -eq 0 ]; then
    echo "-> Paquetes: ya están los ${#paquetes_markdown[@]}, no hay nada que instalar."
else
    echo "-> Instalando: ${faltantes[*]}"
    sudo pacman -S --needed --noconfirm "${faltantes[@]}"
fi

# ==========================================
# 4. EL .DESKTOP DE GLOW
# ==========================================
# El Exec envuelve glow en ghostty porque glow es una TUI y quien lo invoca
# (Thunar, xdg-open) no le da terminal. Es el mismo truco que el atajo SUPER + A
# de hyprland.lua, sin el fallback a less: acá glow es el punto.
mkdir -p "$HOME/.local/share/applications"
ln -sfn "$REPO/applications/glow.desktop" \
    "$HOME/.local/share/applications/glow.desktop"
echo "-> Enlazado: ~/.local/share/applications/glow.desktop -> ~/config_files/applications/glow.desktop"

# Sin esto el .desktop existe pero no está en mimeinfo.cache, así que xdg-open no
# lo encuentra al resolver text/markdown.
if command -v update-desktop-database > /dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
fi

# Thunar se queda de demonio en segundo plano aunque cierres todas las ventanas, y
# se trae las asociaciones al arrancar. Sin este 'thunar -q' el doble clic puede
# seguir yendo a Sublime hasta el próximo login. La siguiente vez que abras una
# carpeta, Thunar arranca solo.
if pgrep -x thunar >/dev/null 2>&1; then
    echo "-> Reiniciando Thunar para que tome la asociación nueva..."
    thunar -q || true
fi

# ==========================================
# 5. VERIFICACIÓN
# ==========================================
# Se comprueban los DOS caminos por separado, que es justo lo que confunde cuando
# falla: el handler sale de mimeapps.list y es común a los dos, pero la detección
# del tipo es distinta en cada uno y es ahí donde se rompía.
echo "---"
handler="$(xdg-mime query default text/markdown 2>/dev/null || true)"
if [ "$handler" = "glow.desktop" ]; then
    echo "OK  handler de text/markdown: $handler"
else
    echo "!!  handler de text/markdown: ${handler:-(ninguno)} -- se esperaba glow.desktop"
fi

# Un archivo de prueba de verdad: la detección por extensión necesita un nombre
# que termine en .md, así que no alcanza con preguntarle a xdg-mime en abstracto.
prueba="$(mktemp --suffix=.md)"
printf '# prueba\n' > "$prueba"

tipo_cli="$(xdg-mime query filetype "$prueba" 2>/dev/null || true)"
if [ "$tipo_cli" = "text/markdown" ]; then
    echo "OK  xdg-open (terminal) ve un .md como: $tipo_cli"
else
    echo "!!  xdg-open (terminal) ve un .md como: ${tipo_cli:-(nada)} -- se esperaba text/markdown."
    echo "    Con eso va a abrir el handler de ese tipo y no glow. ¿Quedó instalado"
    echo "    perl-file-mimeinfo? Probá: mimetype --brief --dereference archivo.md"
fi

if command -v gio > /dev/null; then
    tipo_gui="$(gio info "$prueba" 2>/dev/null | awk -F': ' '/standard::content-type/{print $2; exit}')"
    if [ "$tipo_gui" = "text/markdown" ]; then
        echo "OK  Thunar/GLib ve un .md como: $tipo_gui"
    else
        echo "!!  Thunar/GLib ve un .md como: ${tipo_gui:-(nada)} -- se esperaba text/markdown."
    fi
fi

rm -f "$prueba"

echo "---"
echo "=== Equipo actualizado ==="
echo "Markdown: doble clic en un .md desde Thunar, o 'xdg-open notas.md' desde la"
echo "          terminal, abre glow en una ventana de ghostty. Se sale con 'q'."
echo "          Para editarlo en Sublime sigue estando el 'Abrir con' de Thunar."

exit 0
