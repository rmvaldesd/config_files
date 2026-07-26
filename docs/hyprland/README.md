# Escritorio (Hyprland)

Referencia de atajos y comportamientos del entorno. Todo lo de acá sale de los
archivos versionados en este repo; si cambiás uno, actualizá la sección
correspondiente en el mismo commit.

**Modificadores**

| Nombre en la config | Teclas |
|---|---|
| `mainMod` | `SUPER` (tecla Windows) |
| `secondMod` | `SUPER + SHIFT` |
| `thirdMod` | `SUPER + CONTROL` |

## Índice

- [Ventanas](#ventanas)
- [Workspaces](#workspaces)
- [Aplicaciones y sesión](#aplicaciones-y-sesión)
- [Capturas de pantalla](#capturas-de-pantalla)
- [Teclas multimedia](#teclas-multimedia)
- [Terminal: fzf](#terminal-fzf)
- [Terminal: función `imgs`](#terminal-función-imgs)
- [Portapapeles](#portapapeles)
- [Impresión: `add-printer`](#impresión-add-printer)
- [Waybar: clics](#waybar-clics)
- [Visores](#visores)
- [Comportamiento automático](#comportamiento-automático)
- [Dónde vive cada configuración](#dónde-vive-cada-configuración)
- [Paleta](#paleta)

---

## Ventanas

| Atajo | Acción |
|---|---|
| `SUPER + H` / `L` / `I` / `K` | Mover el **foco** a izquierda / derecha / arriba / abajo |
| `SUPER + SHIFT + H` / `L` / `I` / `K` | **Mover la ventana** en esa dirección |
| `SUPER + SHIFT + C` | Cerrar la ventana |
| `SUPER + V` | Alternar flotante |
| `SUPER + SHIFT + T` | Alternar flotante (mismo efecto que `SUPER + V`) |
| `SUPER + SHIFT + F` | Maximizar |
| `SUPER + P` | Modo pseudo |
| `SUPER + R` | Entrar al **modo redimensionar** (ver abajo) |
| `SUPER + click izquierdo` (arrastrando) | Mover la ventana con el mouse |
| `SUPER + click derecho` (arrastrando) | Redimensionar con el mouse |

### Modo redimensionar

`SUPER + R` entra a un submodo donde las teclas cambian de significado. Se sale
con `Return` o `Escape`.

| Tecla | Acción |
|---|---|
| `H` / `L` | Angostar / ensanchar (10 px) |
| `I` / `J` | Achicar / agrandar en alto (10 px) |
| `Return` o `Escape` | Salir del modo |

> **Ojo con la inconsistencia:** para mover el foco, arriba/abajo son `I`/`K`;
> dentro del modo redimensionar son `I`/`J`. No es un error de este documento,
> es como está en la config.

## Workspaces

| Atajo | Acción |
|---|---|
| `SUPER + 1` … `9`, `0` | Ir al workspace 1-9 y 10 |
| `SUPER + SHIFT + 1` … `9`, `0` | Mover la ventana a ese workspace |
| `SUPER + CONTROL + H` / `K` | Workspace anterior |
| `SUPER + CONTROL + L` / `J` | Workspace siguiente |
| `SUPER + rueda del mouse` | Cambiar de workspace |
| `SUPER + S` | Mostrar/ocultar el workspace especial *magic* |
| `SUPER + SHIFT + S` | Mandar la ventana al workspace *magic* |

## Aplicaciones y sesión

| Atajo | Acción |
|---|---|
| `SUPER + T` | Terminal (ghostty) |
| `SUPER + B` | Navegador (firefox) |
| `SUPER + E` | Gestor de archivos (thunar) |
| `SUPER + Space` | Lanzador de apps (`rofi -show drun`, con iconos) |
| `SUPER + SHIFT + Space` | Ejecutar comando (`rofi -show run`) |
| `SUPER + SHIFT + V` | Historial del portapapeles (cliphist en rofi) |
| `SUPER + SHIFT + Q` | Bloquear la pantalla (hyprlock) |
| `SUPER + SHIFT + M` | Menú de apagado (hyprshutdown) |
| `SUPER + A` | **Esta ayuda**, en una terminal flotante |

> Abre este documento con `glow` si está instalado, y cae a `less` si no. Se
> cierra con `q`.
>
> **Por qué una letra y no `?`:** el layout de este equipo es `latam`, donde la
> barra `/` no tiene tecla propia (se escribe con `Shift + 7`). Un bind sobre el
> keysym `slash` no se dispara con la combinación que uno esperaría. Las letras
> están en la misma posición física en cualquier layout.

## Capturas de pantalla

Todas van sobre la tecla `Print`. Las de región **congelan la pantalla** al
seleccionar, así podés capturar menús desplegados y tooltips.

| Atajo | Captura | Destino |
|---|---|---|
| `Print` | Región | Se abre en **satty** para anotar → `Enter` copia y cierra |
| `SHIFT + Print` | Región | Portapapeles, directo |
| `CONTROL + Print` | Región | `~/Pictures/screenshots` **y** portapapeles |
| `ALT + Print` | Ventana activa | Portapapeles |
| `SUPER + Print` | Monitor completo | Portapapeles |

## Teclas multimedia

Funcionan también con la pantalla bloqueada.

| Tecla | Acción |
|---|---|
| Subir / bajar volumen | ±5 % (con tope en 100 %) |
| Silenciar | Alterna el silencio de la salida |
| Silenciar micrófono | Alterna el silencio de la entrada |
| Brillo + / − | ±5 %, con curva logarítmica y mínimo del 2 % |
| Play / Pausa | Alterna reproducción (playerctl) |
| Siguiente / Anterior | Cambia de pista |

## Terminal: fzf

| Atajo | Acción |
|---|---|
| `Ctrl + R` | Buscar en el historial de comandos |
| `Ctrl + T` | Insertar la ruta de un archivo en la línea actual |
| `Alt + C` | `cd` a un subdirectorio |
| `**` + `Tab` | Autocompletado difuso, ej: `vim **<TAB>` |

Las búsquedas usan `fd`, así que respetan `.gitignore` y saltan los ocultos.

## Terminal: función `imgs`

Busca imágenes mostrando una **vista previa dentro de la terminal**.

```sh
imgs              # desde el directorio actual
imgs ~/Pictures   # desde el que le pases
```

| Tecla | Acción |
|---|---|
| Escribir | Filtra por nombre |
| `Enter` | Abre la imagen con el visor predeterminado |
| `Ctrl + Y` | **Copia la imagen al portapapeles** y cierra |
| `Esc` | Cancela |

Busca `png`, `jpg`, `jpeg`, `gif`, `webp` y `bmp`.

## Portapapeles

`SUPER + SHIFT + V` abre el historial en rofi: elegís una entrada y queda
copiada, lista para pegar con `Ctrl + V`.

Lo sostiene `wl-paste --watch cliphist store`, que arranca con la sesión y
guarda cada cosa que copiás. Es lo que resuelve el problema clásico de Wayland:
sin ese vigilante, lo copiado **muere al cerrar la aplicación de origen**.
Guarda también imágenes.

| Comando | Qué hace |
|---|---|
| `cliphist list` | Ver el historial |
| `cliphist wipe` | **Vaciarlo entero** |
| `cliphist list \| fzf \| cliphist decode \| wl-copy` | Elegir con fzf en vez de rofi |

`cliphist wipe` es el que importa tener a mano: si copiaste una contraseña o un
token, ahí queda guardado hasta que lo borres. La base vive en
`~/.cache/cliphist/db`.

## Impresión: `add-printer`

Descubre las impresoras de la red y las da de alta en CUPS, sin tener que
acordarse de la sintaxis de `lpadmin`.

```sh
add-printer
```

Corre en bucle sobre un menú, así que se pueden encadenar operaciones sin
relanzarlo:

| Opción | Qué hace |
|---|---|
| `1` Add | Lista lo que hay en la red y da de alta la que elijas |
| `2` Remove | Lista las colas ya configuradas y borra la elegida |
| `3` List | Muestra las colas y cuál es la predeterminada |
| `4` Rescan | Vuelve a escanear (el resultado se cachea porque tarda unos segundos) |
| `q` | Salir |

Al agregar, marca cada impresora según sea **driverless** (IPP Everywhere: no
necesita driver) o que **podría necesitar el de la marca**, y muestra hostname,
IP y si es color o monocromática. Después propone el nombre de la cola, ofrece
dejarla predeterminada e imprimir una página de prueba.

Al eliminar pide escribir el nombre completo de la cola, no un `s/n`: borrar no
se deshace. Borra la cola de CUPS, no toca la impresora.

El descubrimiento no pide privilegios; sólo el `lpadmin` final usa sudo.

```sh
lpstat -p -d      # ver colas y predeterminada
lp archivo.pdf    # imprimir en la predeterminada
cancel -a         # vaciar la cola
```

Si algo falla, el detalle está en `docs/linux/impresion.md`: descubrimiento a
mano, drivers por marca y diagnóstico.

## Waybar: clics

| Módulo | Clic izquierdo abre |
|---|---|
| Reloj | Google Calendar (chromium en modo app) |
| Volumen | pavucontrol |
| Batería | — (`format-alt`: alterna a tiempo restante) |
| Perfil de energía | Cicla entre performance / balanced / power-saver |
| Bluetooth | bluetui, en una terminal |
| Red | nmtui, en una terminal |
| CPU | btop, en una terminal |
| Memoria | htop, en una terminal |
| Idioma del teclado | Cambia al siguiente layout |

## Visores

Atajos propios de cada aplicación, no configurados por nosotros, pero útiles
porque son las apps asociadas por defecto.

**imv** (imágenes) — abre toda la carpeta, no solo el archivo elegido

| Tecla | Acción |
|---|---|
| `n` / `p` | Imagen siguiente / anterior |
| `+` / `-` | Zoom |
| `x` | Cerrar la imagen actual |
| `q` | Salir |

**zathura** (PDF)

| Tecla | Acción |
|---|---|
| `j` / `k` | Desplazar |
| `/` | Buscar |
| `+` / `-` | Zoom |
| `q` | Salir |

**mpv** (video y audio)

| Tecla | Acción |
|---|---|
| `Espacio` | Pausa |
| `←` / `→` | Saltar 5 s |
| `9` / `0` | Volumen |
| `f` | Pantalla completa |
| `q` | Salir |

**rofi** — `Enter` selecciona, `Esc` cancela, flechas o `Ctrl+J`/`Ctrl+K` navegan.

## Comportamiento automático

### Inactividad

| Tiempo | Qué pasa |
|---|---|
| 2 min 30 s | Se apaga el backlight del teclado |
| 9 min | Baja el brillo al 10 % — **aviso** de que va a bloquear |
| 10 min | Bloquea con hyprlock |
| 10 min 30 s | Apaga la pantalla (DPMS) |
| 15 min | Suspende, **solo si está en batería** |

El brillo se guarda y se restaura, así que al volver queda como lo tenías. El
bloqueo va **antes** que el apagado de pantalla a propósito: al revés dejaría la
sesión abierta detrás de una pantalla negra.

Si hay un inhibidor activo (por ejemplo un video reproduciéndose en el
navegador), no se bloquea.

### Perfil de energía

Cambia solo al conectar o desconectar el cargador:

| Estado | Perfil |
|---|---|
| Enchufado | `performance` |
| En batería | `balanced` |

También se resincroniza al bootear y al despertar de la suspensión. Un cambio
manual desde el ícono de Waybar dura hasta el siguiente de esos eventos.

### Fondo de pantalla

En cada login se elige **una imagen al azar** de `wallpapers/`, y queda fija el
resto de la sesión. Para sumar fondos, copiá imágenes ahí: entran solas en la
rotación.

Lo hace hyprpaper solo, con `path` apuntando al directorio y `order = random`.
Si querés que además vaya cambiando durante la sesión, agregá
`timeout = <segundos>` al bloque `wallpaper` de `hyprpaper.conf`.

### Notificaciones

Desaparecen a los **5 segundos**. Las de urgencia crítica (batería baja, etc.)
no expiran solas.

### Asociaciones de archivos

| Tipo | Abre con |
|---|---|
| Imágenes (17 formatos) | imv |
| `.xcf` (formato nativo de GIMP) | GIMP |
| PDF | zathura |
| Video y audio (122 formatos) | mpv |
| Texto y código (23 tipos) | Sublime Text |
| Documentos de oficina (134 tipos) | LibreOffice (writer, calc, impress, draw, base, math) |
| HTML y enlaces `http` / `https` | Firefox |

Dos tipos quedaron **deliberadamente fuera** de LibreOffice aunque los declara:
`application/pdf` sigue en zathura (Draw los *edita*; para leerlos zathura es
mejor) y `text/plain` en Sublime Text, porque abrir un `.txt` o un log en un
procesador de texto no es lo que uno espera de un doble clic.

Los `.csv` sí van a Calc: se leen mucho mejor como planilla. Para verlos en
crudo, `sublime archivo.csv` desde la terminal.

GIMP está instalado pero **solo** se asocia a `.xcf`: para el resto de las
imágenes queda en el menú *Abrir con* de Thunar, porque es un editor y no tiene
sentido levantarlo para mirar un PNG.

Las asociaciones viven en `mimeapps.list`, versionado. Si cambiás una desde
Thunar (*Abrir con → Establecer como predeterminada*), el cambio se guarda ahí
solo: `xdg-mime` escribe a través del symlink.

## Dónde vive cada configuración

| Qué | Archivo |
|---|---|
| Atajos de Hyprland, autostart | `dotconfig/hypr/hyprland.lua` |
| Inactividad y bloqueo | `dotconfig/hypr/hypridle.conf` |
| Pantalla de bloqueo | `dotconfig/hypr/hyprlock.conf` |
| Fondo de pantalla | `dotconfig/hypr/hyprpaper.conf` |
| Barra: módulos | `dotconfig/waybar/config.jsonc` |
| Barra: estilo | `dotconfig/waybar/style.css` |
| Notificaciones | `dotconfig/mako/config` |
| Lanzador | `dotconfig/rofi/config.rasi` y `dark.rasi` |
| Terminal | `dotconfig/ghostty/config.ghostty` |
| fzf y función `imgs` | `zshrc.local` |
| Asociaciones de archivos | `mimeapps.list` |
| Ignore global de git | `dotconfig/git/ignore` |
| Perfiles de energía | `etc/systemd/system/`, `etc/udev/rules.d/`, `etc/polkit-1/rules.d/`, `bin_configs/power-profile-sync` |
| Asistente de impresión | `bin_configs/add-printer` (enlazado en `/usr/local/bin`) |
| Instalación completa | `archdesktopinstall.sh` |

Todo lo de `dotconfig/` se enlaza con symlinks a `~/.config/`; lo de `etc/` se
**copia** a `/etc` (lo lee root o udev antes de que se monte `/home`).

## Paleta

El entorno entero usa los mismos colores: la escala **Zinc** de Tailwind más dos
acentos. La regla que la ordena es que el gris marca **foco y estructura**, y el
cyan queda para **progreso e interacción**.

| Color | Zinc | Uso |
|---|---|---|
| `#18181b` | 950 | Fondo de la barra, negro base |
| `#27272a` | 800 | Reglas verticales entre módulos de la barra, terminal |
| `#3f3f46` | 700 | Borde de ventana **inactiva**, borde de las notificaciones |
| `#52525b` | 600 | Final del degradado del borde de ventana activa |
| `#71717a` | 500 | Workspaces inactivos |
| `#d4d4d8` | 300 | Borde de ventana **activa** (inicio) y subrayado del workspace activo |
| `#fafafa` | 50 | Texto |
| `#75f1fa` | — | Acento cyan: progreso e interacción (slider de volumen, día de hoy en el calendario, acento de rofi) |
| `#e35149` | — | Estados urgentes y de error |

Los módulos de la barra **no tienen fondo**: la única separación es la regla
vertical de 1px, recortada arriba y abajo.
