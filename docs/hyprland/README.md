# Escritorio (Hyprland)

Referencia rápida de atajos y comportamientos.

**Modificadores**
- `mainMod` = SUPER · `secondMod` = SUPER+SHIFT · `thirdMod` = SUPER+CONTROL

---

## Ventanas

- **SUPER + H/L/K/J** → mover foco (izq / der / arriba / abajo)
- **SUPER + SHIFT + H/L/K/J** → mover la ventana en esa dirección
- **SUPER + SHIFT + C** → cerrar ventana
- **SUPER + V** → alternar flotante
- **SUPER + SHIFT + T** → alternar flotante (igual que V)
- **SUPER + SHIFT + F** → maximizar (respeta waybar y gaps)
- **SUPER + CTRL + F** → pantalla completa
- **SUPER + P** → modo pseudo (duplica la ventana en el layout)
- **SUPER + click izq** → mover ventana con mouse
- **SUPER + click der** → redimensionar con mouse

### Modo redimensionar (SUPER + R)

Teclas cambian de significado. Salir con **Return** o **Escape**.

- **H/L** → angostar / ensanchar (10 px)
- **K/J** → achicar / agrandar en alto (10 px)

---

## Workspaces

- **SUPER + 1…9, 0** → ir al workspace 1–10
- **SUPER + SHIFT + 1…9, 0** → mover ventana a ese workspace
- **SUPER + CTRL + H/K** → workspace anterior
- **SUPER + CTRL + L/J** → workspace siguiente
- **SUPER + rueda del mouse** → cambiar de workspace
- **SUPER + CTRL + SHIFT + H/L** → arrastrar workspace una posición a la izq / der
- **SUPER + CTRL + SHIFT + K/J** → arrastrar workspace a la izq / der (equivalente)
- **SUPER + S** → mostrar/ocultar workspace especial *magic*
- **SUPER + SHIFT + S** → mandar ventana al workspace *magic*
- **SUPER + CTRL + M** → renumerar workspaces a 1..N en orden visual

### Modo monitor (SUPER + M)

Mover el **workspace activo entero** a otra pantalla. Salir con **Return** o **Escape** (al salir renumera automáticamente).

- **H/←** → pantalla izquierda
- **L/→** → pantalla derecha
- **K/↑** → pantalla arriba
- **J/↓** → pantalla abajo

Empujar contra un borde sin pantalla no hace nada (Hyprland avisa "Monitor not found").

---

## Aplicaciones y sesión

- **SUPER + Return** → terminal (foot)
- **SUPER + B** → navegador (firefox)
- **SUPER + E** → gestor de archivos (thunar)
- **SUPER + F** → buscar archivo en `~` y abrirlo (find-file); si tenés una ruta o URL copiada, la ofrece primero
- **SUPER + Space** → lanzador de apps (rofi drun)
- **SUPER + SHIFT + Space** → ejecutar comando (rofi run)
- **SUPER + SHIFT + V** → historial del portapapeles (cliphist en rofi)
- **SUPER + W** → selector de ventanas del workspace actual
- **SUPER + SHIFT + W** → selector de todas las ventanas (salta al workspace)
- **SUPER + SHIFT + Q** → bloquear pantalla (hyprlock)
- **SUPER + D** → **emergencia:** encender pantalla si quedó negra
- **SUPER + SHIFT + M** → menú de apagado
- **SUPER + A** → esta ayuda (terminal flotante con glow o less)

---

## Capturas de pantalla

Congelan la pantalla al seleccionar, así podés capturar menús desplegados.

- **Print** → región → se abre en satty para anotar → `Enter` copia y cierra
- **SHIFT + Print** → región → portapapeles directo
- **CTRL + Print** → región → `~/Pictures/screenshots` + portapapeles
- **ALT + Print** → ventana activa → portapapeles
- **SUPER + Print** → monitor completo → portapapeles

---

## Teclas multimedia (funcionan con pantalla bloqueada)

- Subir / bajar volumen: ±5% (tope 100%)
- Silenciar: alterna la salida
- Silenciar micrófono: alterna la entrada
- Brillo +/−: ±5%, curva logarítmica, mínimo 2%
- Play / Pausa: alterna reproducción (playerctl)
- Siguiente / Anterior: cambia de pista

---

## Terminal: fzf

Dos puntos de entrada: **rutas** (`Ctrl+F`) y **contenido** (`Ctrl+G`).

- **Ctrl+F** → buscar rutas e insertar en la línea actual
- **Ctrl+G** → buscar contenido (ripgrep), inserta `+línea archivo`
- **Ctrl+R** → buscar en historial de comandos
- **Ctrl T** → archivos del directorio actual (el que trae fzf de fábrica)
- **Alt + C** → `cd` a un subdirectorio
- **`**` + Tab → autocompletado difuso

Dentro de `Ctrl+F` y `Ctrl+G`:

- **Ctrl+H** → ampliar búsqueda a `~`
- **Ctrl+L** → volver al directorio actual
- **Ctrl+F** → modo archivos (solo en `Ctrl+F`)
- **Ctrl+D** → modo directorios (solo en `Ctrl+F`)

`Ctrl+F` permite elegir varios con Tab. Si lo último es un directorio no agrega espacio al final.

---

## Terminal: función `imgs`

Busca imágenes con vista previa en la terminal.

- `imgs` → desde el directorio actual
- `imgs ~/Pictures` → desde el que le pases

- **Escribir** → filtra por nombre
- **Enter** → abre con el visor predeterminado
- **Ctrl + Y** → copia la imagen al portapapeles y cierra
- **Esc** → cancela

Soporta: `png`, `jpg`, `jpeg`, `gif`, `webp`, `bmp`.

---

## Portapapeles

- `cliphist list` → ver historial
- `cliphist wipe` → vaciar todo
- `cliphist list | fzf | cliphist decode | wl-copy` → elegir con fzf

La base vive en `~/.cache/cliphist/db`. `cliphist wipe` es lo que importa tener a mano si copiaste una contraseña o token.

---

## Selector de ventanas (`pick-window`)

- `SUPER + W` → ventanas del workspace actual
- `SUPER + SHIFT + W` → todas las ventanas (salta al workspace elegido)

Se puede llamar suelto: `pick-window` / `pick-window --all`

---

## Buscador de archivos (`find-file`)

`SUPER + F` busca en todo `~` y abre con la app por defecto (PDF → zathura, PNG → imv, texto → Sublime). Menú con nombre + carpeta, filtrable.

- `find-file` → elige frontend automáticamente (rofi desde bind, fzf en terminal)
- `find-file --rofi` → fuerza rofi
- `find-file --fzf` → fuerza fzf

### Lo que tengas copiado: ruta o URL (solo cara rofi)

Si lo último copiado es una ruta (con `copy-path`, `screenshot-path`, un editor) o una URL (de un navegador), el menú de `SUPER + F` lo muestra **arriba de todo y preseleccionado**: Enter sin escribir nada abre eso. `Alt+1` lo abre igual aunque el filtro lo haya tapado.

- Se miran las **primeras 5 líneas** del portapapeles, y las filas salen **en el orden** en que vinieron.
- **Rutas:** antes de ofrecerlas se las limpia (`file://`, escapes `%20`, comillas, CR final, espacios, `~`, relativas y el sufijo `:línea:col` de editores y `grep`). Si el archivo **existe** pero `fd` no lo listaría (está fuera de `~` o en una carpeta excluida), se lo **inyecta igual** como fila fija; si ya estaba en la lista, no se duplica. Si **no existe**, se muestra marcada `[portapapeles] no existe` y al elegirla solo avisa (no abre).
- **URLs:** cualquier `esquema://` (`http`, `https`, `ftp`, `gemini`, `ssh`, …) o `mailto:`, marcada `[portapapeles] url`, y se abre con el manejador por defecto vía `xdg-open` (hoy `google-chrome` para `http(s)`; **no** usa el firefox de `SUPER + B`). A diferencia de las rutas, a una URL **no** se le decodifican los `%`: cambiaría su significado. Si el esquema no tiene manejador, avisa en vez de abrir.
- `file://…` no cuenta como URL: es una ruta local y va por la rama de archivos (un `.html` local ya se abre con el navegador por `text/html`).
- Si el portapapeles tiene texto que no parece ni ruta ni URL (o una imagen), no se ofrece nada.

Excluidos de la búsqueda: `.git`, `.cache`, `.cargo`, `.claude`, `.local/share`, `.local/state`, `go/pkg`, `.npm`, `node_modules`, `.oh-my-zsh`.

---

## Impresión (`add-printer`)

Descubre impresoras de red y las da de alta en CUPS.

- `1` Add → lista la red y da de alta la que elijas
- `2` Remove → lista colas configuradas y borra la elegida
- `3` List → muestra colas y cuál es la predeterminada
- `4` Rescan → vuelve a escanear
- `q` → salir

- `lpstat -p -d` → ver colas y predeterminada
- `lp archivo.pdf` → imprimir en la predeterminada
- `cancel -a` → vaciar la cola

---

## Mantenimiento

### RAM: `ram-top`

Suma por aplicación (no por proceso). Mide con PSS, no RSS.

- `ram-top` → modo interactivo con teclas de vim (j/k/g/G/Ctrl-D/Ctrl-U, `/` buscar, `q` salir)
- `ram-top -p` → salida de texto
- `ram-top firefox` → solo esa aplicación
- `ram-top -n 20` → cuántas mostrar
- `ram-top -t` → con detalle de procesos
- `ram-top --rss` → mostrar RSS junto a PSS

En la segunda vista (procesos): `l` o `Enter` entra, `h` o `Escape` vuelve, `Ctrl-O` oculta el panel, `Ctrl-R` relee.

### Paquetes huérfanos: `clean-orphans`

Lista huérfanos con tamaño, pide confirmación y los elimina (en rondas hasta que no quede ninguno).

- `pacman -Qdt` → ver huérfanos sin tocar nada
- `pacman -Qm` → paquetes de AUR

### Scripts propios

- `bash ~/config_files/scripts/link-bins.sh` → crear symlinks de `bin_configs/` a `/usr/local/bin` (idempotente)

### Actualizar un equipo rezagado

- `bash ~/config_files/scripts/update-since-*.sh` → scripts idempotentes que van más allá de un `git pull` (paquetes nuevos, reiniciar procesos). Ejecutarlos en un equipo al día no cambia nada.

---

## Waybar: clics

- **Workspaces** → ir a ese workspace
- **Reloj** → Google Calendar (chromium en modo app)
- **Volumen** → wiremix (en terminal)
- **Batería** → `format-alt`: alterna a tiempo restante
- **Perfil de energía** → cicla performance / balanced / power-saver
- **Bluetooth** → bluetui (en terminal)
- **Sync con Drive** → menú de rclone-sync (clic derecho: el log)
- **Red** → nmtui (en terminal)
- **CPU** → btop (en terminal)
- **Swap** → htop (en terminal)
- **Memoria** → `ram-top` (ventana flotante)
- **Disco** → btop (en terminal)
- **Idioma del teclado** → cambia al siguiente layout

---

## Visores (atajos propios)

**imv** (imágenes): `n`/`p` siguiente/anterior · `+`/`-` zoom · `x` cerrar · `q` salir

**zathura** (PDF): `j`/`k` desplazar · `/` buscar · `+`/`-` zoom · `q` salir

**mpv** (video/audio): `Espacio` pausa · `←`/`→` saltar 5s · `9`/`0` volumen · `f` pantalla completa · `q` salir

**rofi**: `Enter` seleccionar · `Esc` cancelar · flechas o `Ctrl+J`/`Ctrl+K` navegar

---

## Archivos comprimidos

Clic derecho en Thunar: **Extraer aquí** (crea carpeta si no está envuelto) / **Extraer en…** / **Comprimir…**

Formatos cubiertos: zip, rar (solo extraer, no crear), 7z, tar y variantes (`.tar.gz`, `.tar.xz`, `.tar.zst`, `.tar.bz2`), cab, iso, rpm.

Formato raro que no abre: `pacman -Si xarchiver` lista paquetes necesarios en *Optional Deps*.

Si instalás el plugin con Thunar ya corriendo: `thunar -q` para reiniciarlo.

---

## Comportamiento automático

### Inactividad

- 2m 30s → backlight del teclado se apaga
- 9 min → brillo baja al 10% (aviso)
- 10 min → hyprlock
- 10m 30s → pantalla off (DPMS)
- 15 min → suspende (solo en batería)

Inhibidor activo = no se bloquea.

### Perfil de energía

- Enchufado → `performance`
- Batería → `balanced`

Se resincroniza al boot y al despertar.

### Fondo de pantalla

Imagen al azar de `wallpapers/` en cada login, fija el resto de la sesión.

### Notificaciones

Desaparecen a los 5 segundos. Urgencia crítica no expira sola.

---

## Paleta (Zinc de Tailwind + acentos)

- `#18181b` (950) → fondo de la barra
- `#27272a` (800) → separadores de módulos, terminal
- `#3f3f46` (700) → borde de ventana inactiva
- `#52525b` (600) → borde de ventana activa (fin del degradado)
- `#71717a` (500) → workspaces inactivos
- `#d4d4d8` (300) → borde de ventana activa (inicio), workspace activo
- `#fafafa` (50) → texto
- `#75f1fa` → cyan: progreso e interacción
- `#e35149` → estados urgentes / error

---

## Dónde vive cada configuración

- Hyprland (atajos, autostart): `dotconfig/hypr/hyprland.lua`
- Inactividad / bloqueo: `dotconfig/hypr/hypridle.conf`
- Pantalla de bloqueo: `dotconfig/hypr/hyprlock.conf`
- Fondo de pantalla: `dotconfig/hypr/hyprpaper.conf`
- Waybar (módulos): `dotconfig/waybar/config.jsonc`
- Waybar (estilo): `dotconfig/waybar/style.css`
- Módulo swap / disco: `dotconfig/waybar/scripts/swap.sh` / `disk.sh`
- Notificaciones: `dotconfig/mako/config`
- Lanzador: `dotconfig/rofi/config.rasi` y `dark.rasi`
- Terminal: `dotconfig/ghostty/config.ghostty`
- fzf / imgs / PATH / hook direnv: `zshrc.local`
- Asociaciones de archivos: `mimeapps.list`
- Scripts propios (enlazados): `bin_configs/` → `/usr/local/bin/` vía `scripts/link-bins.sh`
- Instalación completa: `archdesktopinstall.sh`
