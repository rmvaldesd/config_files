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
- [Waybar: clics](#waybar-clics)
- [Visores](#visores)
- [Comportamiento automático](#comportamiento-automático)
- [Dónde vive cada configuración](#dónde-vive-cada-configuración)

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

## Waybar: clics

| Módulo | Clic izquierdo abre |
|---|---|
| Reloj | Google Calendar (chromium en modo app) |
| Volumen | pavucontrol |
| Batería | — (`format-alt`: alterna a tiempo restante) |
| Perfil de energía | Cicla entre performance / balanced / power-saver |
| Bluetooth | bluetui, en una terminal |
| Red | nmrs |
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

En cada login se elige **una imagen al azar** de `wallpapers/`. Para sumar
fondos, copiá imágenes ahí: entran solas en la rotación.

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
| Texto y código (24 tipos) | Sublime Text |
| HTML y enlaces `http` / `https` | Firefox |

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
| Fondo de pantalla (fallback) | `dotconfig/hypr/hyprpaper.conf` |
| Fondo aleatorio | `bin_configs/hyprpaper-random` |
| Barra: módulos | `dotconfig/waybar/config.jsonc` |
| Barra: estilo | `dotconfig/waybar/style.css` |
| Notificaciones | `dotconfig/mako/config` |
| Lanzador | `dotconfig/rofi/config.rasi` y `dark.rasi` |
| Terminal | `dotconfig/ghostty/config.ghostty` |
| Gestor de red | `dotconfig/nmrs/style.css` |
| fzf y función `imgs` | `zshrc.local` |
| Asociaciones de archivos | `mimeapps.list` |
| Ignore global de git | `dotconfig/git/ignore` |
| Perfiles de energía | `etc/systemd/system/`, `etc/udev/rules.d/`, `etc/polkit-1/rules.d/`, `bin_configs/power-profile-sync` |
| Instalación completa | `archdesktopinstall.sh` |

Todo lo de `dotconfig/` se enlaza con symlinks a `~/.config/`; lo de `etc/` se
**copia** a `/etc` (lo lee root o udev antes de que se monte `/home`).

## Paleta

El entorno entero usa los mismos colores:

| Color | Uso |
|---|---|
| `#18181b` | Fondo de la barra, negro base |
| `#27272a` | Fondo de módulos, terminal, ventanas |
| `#3f3f46` | Bordes |
| `#52525b` | Bordes al pasar el mouse, selección |
| `#fafafa` | Texto |
| `#75f1fa` | Acento (cyan) |
| `#e35149` | Estados urgentes y de error |
