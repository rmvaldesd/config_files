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
- [Selector de ventanas: `pick-window`](#selector-de-ventanas-pick-window)
- [Buscador de archivos: `find-file`](#buscador-de-archivos-find-file)
- [Impresión: `add-printer`](#impresión-add-printer)
- [Mantenimiento](#mantenimiento)
- [Waybar: clics](#waybar-clics)
- [Swap en la barra](#swap-en-la-barra)
- [Disco en la barra](#disco-en-la-barra)
- [Visores](#visores)
- [Archivos comprimidos](#archivos-comprimidos)
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
| `SUPER + CONTROL + H` / `K` | Workspace anterior (recorrido 1..N, cruza a la otra pantalla en el borde) |
| `SUPER + CONTROL + L` / `J` | Workspace siguiente (ídem) |
| `SUPER + rueda del mouse` | Cambiar de workspace, mismo recorrido |
| Clic en un número de la barra | Ir a ese workspace |
| `SUPER + CONTROL + SHIFT + H` / `K` | **Arrastrar el workspace** una posición a la izquierda (ver abajo) |
| `SUPER + CONTROL + SHIFT + L` / `J` | … una posición a la derecha |
| `SUPER + S` | Mostrar/ocultar el workspace especial *magic* |
| `SUPER + SHIFT + S` | Mandar la ventana al workspace *magic* |
| `SUPER + M` | Entrar al **modo monitor** (ver abajo) |
| `SUPER + CONTROL + M` | Renumerar los workspaces a 1..N en orden visual (ver abajo) |

### Modo monitor

`SUPER + M` entra a un submodo para mover el **workspace activo entero** de una
pantalla a otra. Se sale con `Return` o `Escape`. *M* de monitor.

| Tecla | Acción |
|---|---|
| `H` o `←` | Mover el workspace a la pantalla de la izquierda |
| `L` o `→` | … a la derecha |
| `I` o `↑` | … arriba |
| `K` o `↓` | … abajo |
| `Return` o `Escape` | Salir del modo **y renumerar** (ver abajo) |

Las flechas hacen exactamente lo mismo que las letras. Acá arriba/abajo son
`I`/`K`, igual que para mover el foco — no como en el modo redimensionar.

Es un modo y no un atajo directo por dos razones: las tres combinaciones
direccionales ya están tomadas (`SUPER` foco, `SUPER + SHIFT` ventana,
`SUPER + CONTROL` workspace), y el caso real no es mover un workspace suelto
sino enchufar el monitor y reacomodar dos o tres seguidos sin salir del modo.

Empujar contra el borde no hace nada: si no hay pantalla de ese lado, Hyprland
avisa *"Monitor not found"* y el workspace se queda donde está. No da la vuelta.

Mientras estés adentro, waybar lo muestra: una **pastilla de color con un icono**,
al principio de los indicadores de la derecha — un monitor y fondo cyan para este
modo, una regla y fondo coral para el modo redimensionar. Es la única pastilla de
la barra, a propósito: un submodo no es un indicador más sino un estado en el que
las teclas hacen otra cosa, y tiene que cantar. Pasando el mouse por encima, el
tooltip dice de qué modo se trata y qué teclas tiene.

### Renumerar: los workspaces quedan 1..N en orden visual

Mover un workspace de pantalla **no le cambia el número**: se va con el que tenía.
Después de reacomodar dos o tres quedan intercalados —

```
antes:    eDP-1 -> 1, 3, 5        DP-1 -> 2, 4, 6, 7
después:  eDP-1 -> 1, 2, 3        DP-1 -> 4, 5, 6, 7
```

— y eso se nota en dos lados: la barra muestra el número (`{id}`) y la navegación
relativa lo recorre. El reordenamiento lo hace `bin_configs/sort-workspaces`, y se
dispara solo **al salir del modo monitor**, que es justo cuando terminaste de
acomodar. `SUPER + CONTROL + M` lo corre a mano.

La pantalla de más a la izquierda se queda con el 1, sin importar cuál sea la
principal: el criterio es la posición física (`x`), que es lo que el ojo espera.
Dentro de cada pantalla se respeta el orden que ya tenían.

**No mueve ventanas.** Usa el dispatcher `workspace.change_id` de la API Lua, que
cambia el número *en el lugar*: las ventanas, el layout, el estado de pantalla
completa y el workspace activo de cada pantalla quedan intactos. La alternativa —
mudar las ventanas de un workspace a otro — habría reconstruido el tiling.

Dos detalles que no son obvios y por eso están en el script:

- **Hace falta un número temporal para romper los ciclos.** Si el 2 va al 3 y el 3
  al 2, el primer cambio chocaría contra un número todavía ocupado. Pero sólo se
  usa cuando de verdad hay un ciclo: primero se mueven los que tienen el destino
  libre —eso resuelve las cadenas (el 5 pasa a 3 cuando el 3 ya se fue) sin gastar
  ninguno— y recién si nadie puede avanzar se estaciona uno en el rango temporal,
  que arranca 100 arriba del ID más alto. En la práctica casi nunca aparece.
- **Todos los cambios van en un solo `hyprctl --batch`.** Cada `hyprctl` suelto es
  un proceso más una ida y vuelta por el socket, y entre uno y otro el estado
  intermedio es visible: se veían aparecer workspaces numerados 109, 110 —los
  temporales— como si hubiera de más. En un lote no hay ventana para eso.

**A la barra no hay que avisarle nada.** El módulo de workspaces es
`ext/workspaces`, que habla el protocolo del compositor y ve los cambios de ID por
su cuenta. Antes esto mandaba un `SIGUSR2`, que no es un refresco sino una
reconstrucción de *todos* los módulos: la barra entera parpadeaba en cada
movimiento, y encadenar esas recargas llegaba a matarla.

Para ver qué haría sin tocar nada:

```sh
sort-workspaces --dry-run
```

> `sort-workspaces` vive en `bin_configs/`, así que en una máquina ya instalada hay
> que crearle el symlink con `bash ~/config_files/scripts/link-bins.sh` (ver
> [Scripts propios](#scripts-propios-link-binssh)). Sin eso el atajo no hace nada,
> aunque el modo monitor sigue saliendo con `Escape` igual.

### Reordenar: arrastrar un workspace de posición

`SUPER + CONTROL + SHIFT + H` / `L` (o `K` / `J`) mueve el workspace **activo** una
posición hacia ese lado, empujando a los demás para que la secuencia siga siendo
1..N sin huecos. Estando en el 1 de `1, 2, 3, 4`, dos veces a la derecha:

```
antes:    1, 2, 3, 4      (parado en el 1)
después:  el que era 1 ahora es 3, el 2 pasó a 1 y el 3 pasó a 2. El 4 no se movió.
```

Seguís parado en el mismo workspace y con las mismas ventanas: lo único que cambia
es su número, o sea su lugar en la barra y en el recorrido de la navegación
relativa.

Son las mismas teclas que la navegación entre workspaces más `SHIFT`, que es la
convención del resto de la config: `SUPER + n` **enfoca** el workspace n y
`SUPER + SHIFT + n` **mueve** la ventana ahí; acá `SUPER + CONTROL + H` enfoca el
workspace vecino y agregarle `SHIFT` mueve el workspace hacia ese lado.

**No cruza de pantalla, y es a propósito.** Esto renumera; mandar un workspace a la
otra pantalla es el [modo monitor](#modo-monitor). Contra los extremos no hace nada
y no se queja. Como reordenar dentro de una pantalla reparte los mismos números
entre los mismos workspaces, el resultado es **estable**: correr `sort-workspaces`
después no lo deshace, así que los dos se pueden usar en cualquier orden.

**Una pulsación, una posición:** el atajo no tiene auto-repetición. Manteniéndolo
apretado el workspace volaba diez o veinte posiciones de un saque, que para
reordenar es puro sobretiro.

Para ver qué haría sin tocar nada, o para saltar directo a una posición:

```sh
move-workspace right --dry-run
move-workspace 3              # a la tercera posición de la pantalla
```

> `move-workspace` también vive en `bin_configs/`: mismo `link-bins.sh` que
> `sort-workspaces`. Sin el symlink, el atajo no hace nada.

## Aplicaciones y sesión

| Atajo | Acción |
|---|---|
| `SUPER + T` | Terminal (ghostty) |
| `SUPER + B` | Navegador (firefox) |
| `SUPER + E` | Gestor de archivos (thunar) |
| `SUPER + F` | Buscar un archivo en todo `~` y abrirlo con su aplicación por defecto |
| `SUPER + Space` | Lanzador de apps (`rofi -show drun`, con iconos) |
| `SUPER + SHIFT + Space` | Ejecutar comando (`rofi -show run`) |
| `SUPER + SHIFT + V` | Historial del portapapeles (cliphist en rofi) |
| `SUPER + W` | Selector de ventanas **del workspace actual** (rofi) |
| `SUPER + SHIFT + W` | Selector de **todas** las ventanas; salta al workspace de la elegida |
| `SUPER + SHIFT + Q` | Bloquear la pantalla (hyprlock) |
| `SUPER + D` | **Salida de emergencia:** enciende la pantalla si quedó negra |
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

Dos puntos de entrada: uno busca **rutas** y el otro **contenido**.

| Atajo | Acción |
|---|---|
| `Ctrl + F` | Buscar rutas e insertarlas en la línea actual |
| `Ctrl + G` | Buscar contenido (ripgrep) e insertar `+línea archivo` |
| `Ctrl + R` | Buscar en el historial de comandos |
| `Ctrl + T` | Archivos del directorio actual (el que trae fzf de fábrica) |
| `Alt + C` | `cd` a un subdirectorio |
| `**` + `Tab` | Autocompletado difuso, ej: `vim **<TAB>` |

Dentro de `Ctrl + F` y `Ctrl + G` se cambia de modo sin tener que salir y
volver a entrar:

| Tecla | Acción | Dónde |
|---|---|---|
| `Ctrl + H` | Ampliar la búsqueda a `~` | En los dos |
| `Ctrl + L` | Volver al directorio actual | En los dos |
| `Ctrl + F` | Modo archivos | Solo en `Ctrl + F` |
| `Ctrl + D` | Modo directorios | Solo en `Ctrl + F` |

En grep no hay modo archivos/directorios: los resultados son siempre líneas.

El prompt dice siempre dónde estás parado — `files ~>`, `dirs .>`, `grep ~>` — y
cambiar de modo conserva lo que ya tipeaste. Cada tecla fija su mitad del estado
y deja la otra como estaba: desde `dirs ~>`, `Ctrl + F` te lleva a `files ~>`.

`Ctrl + F` permite elegir varios con `Tab`. Si lo último que elegís es un
directorio no agrega espacio al final, así seguís tipeando un nombre adentro
(`cp algo ~/dir/…`).

Las búsquedas usan `fd` y `ripgrep`, incluyen los archivos ocultos y respetan
`.gitignore`. Al ampliar a `~` se saltean `.cache`, `.cargo`, `.claude`,
`.local/share` y `.local/state`: sin filtrar son 64.000 archivos y la enorme
mayoría es caché.

Adentro de fzf estas teclas pisan atajos propios de fzf, todos con reemplazo:
`Ctrl + F` (queda `→`), `Ctrl + D` (queda `Supr`), `Ctrl + H` (queda
`Backspace`) y `Ctrl + L` (limpiar pantalla). En la shell, `Ctrl + F` era
`forward-char`; quedan las flechas y `Alt + F`.

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

## Selector de ventanas: `pick-window`

`SUPER + W` (de *window*) abre un menú de rofi con las ventanas del workspace
**actual**: elegís una y salta el foco. Muestra clase y título de cada una y se
filtra escribiendo.

`SUPER + SHIFT + W` hace lo mismo pero con **todas** las ventanas de todos los
workspaces. Al elegir una que está en otro, salta a ese workspace y la enfoca.

En este modo el menú suma una columna con el workspace de cada ventana, y viene
ordenado por ella:

```
ws1   firefox                  Google — Mozilla Firefox
ws1   com.mitchellh.ghostty    ~/config_files
ws2   firefox                  Index of /archlinux/iso/...
```

Eso también la vuelve filtrable: escribir `ws2` en el buscador deja sólo las de
ese workspace.

En los dos casos, si la ventana elegida estaba tapada por otra maximizada, esa
otra se restaura sola. No es algo que haga el script: el dispatcher de foco de
Hyprland ya cambia de workspace y saca el estado maximizado por su cuenta.

También se puede llamar suelto:

```sh
pick-window          # workspace actual
pick-window --all    # todos
```

### Por qué no alcanza con `rofi -show window`

Ese modo lista las ventanas de *todos* los workspaces y no hay forma de
filtrarlas. El modo que sí filtraba por escritorio actual (`windowcd`) existe en
el rofi clásico de X11 pero no en el de Wayland: ahí rofi usa el protocolo
`wlr-foreign-toplevel`, que no expone a qué workspace pertenece cada ventana.

Esa información la tiene Hyprland, así que el script se la pide a él y usa rofi
sólo como menú.

### Por qué `W` y no `SUPER + ALT`

Atar un **modificador** como tecla no funciona. Al pulsar ALT, Hyprland
actualiza el estado de modificadores en vez de mandarlo por el matcher de binds,
así que el bind nunca dispara. Ni siquiera con `release` (el `bindr`, que
engancha el soltar y suele rescatar estos casos). Con cualquier tecla normal
anda a la primera.

## Buscador de archivos: `find-file`

`SUPER + F` (de *find* / *file*) busca un archivo en cualquier lugar de `~` y lo
abre con la aplicación que le corresponda según `mimeapps.list` (un PDF en
zathura, un PNG en imv, texto en Sublime). Es el equivalente gráfico del `Ctrl+F`
de la terminal, y por eso comparte la letra.

El menú muestra dos columnas: el nombre a la izquierda y la carpeta a la
derecha. El nombre es lo que uno recuerda; la carpeta es lo que desempata entre
los diez `README.md` del disco.

```
informe-2026.pdf        ~/Documents/trabajo
notas.md                ~/obsidian/diario
config.rasi             ~/.config/rofi
```

Se filtra escribiendo, y el filtro corre sobre las dos columnas: `pdf trab` deja
sólo los PDF que estén bajo una carpeta de trabajo.

### El mismo comando en la terminal

Corrido a mano, `find-file` cambia de cara: usa **fzf** con un panel de preview
al costado, y con `Tab` se marcan varios para abrirlos todos juntos.

```sh
find-file          # elige solo el frontend
find-file --rofi   # fuerza el menú de rofi
find-file --fzf    # fuerza fzf, incluso desde el bind
```

La detección es por TTY: Hyprland lanza los binds sin terminal, así que ahí sale
rofi; en una terminal interactiva sale fzf. Es el único dato confiable para
distinguir los dos casos — `WAYLAND_DISPLAY`, por ejemplo, está puesto en los
dos, porque la terminal también es un cliente de Wayland.

El preview mira primero si el archivo es binario. Sin ese chequeo, previsualizar
un PDF o una imagen — que son justo los que uno abre con este lanzador — volcaría
bytes crudos al panel y dejaría la terminal desconfigurada. Para esos muestra qué
son y cuánto pesan.

### Qué queda afuera de la búsqueda

Se listan los archivos ocultos (si no, `~/.config` sería invisible), pero se
excluyen a mano los directorios que son caché o código descargado:

| Excluido | Por qué |
|---|---|
| `.git`, `.cache`, `.cargo`, `.claude`, `.local/share`, `.local/state` | Caché y estado de las apps |
| `go/pkg`, `.npm`, `node_modules` | Cachés de dependencias, de sólo lectura |
| `.oh-my-zsh` | Código del framework, no configuración propia |

El segundo bloque es el que más cambia las cosas: sin él el menú pasa de **4.724
entradas a 34.336**, porque el caché de módulos de Go solo aporta 27.216 — el 79%
del total.

Es la **misma** lista que usan los widgets de `Ctrl+F` y `Ctrl+G` de la terminal,
para que buscar desde el escritorio y buscar desde la shell no devuelvan
universos distintos. Vive duplicada en dos lugares y hay que tocar los dos:

| Dónde | Variable |
|---|---|
| `bin_configs/find-file` | arreglo `excluir` |
| `zshrc.local` | `_fzf_home_ex_fd` y `_fzf_home_ex_rg` |

Ojo con la sintaxis de la tercera: `fd` y `rg` **no** tratan igual a los patrones
con barra. `fd --exclude=go/pkg` ancla desde la raíz de la búsqueda y anda desde
cualquier directorio; `rg --glob=!go/pkg` lo ancla al directorio *actual*, así
que desde otro directorio se ignora en silencio (31.877 archivos en vez de
4.661). En `rg` esos patrones van como `--glob="!**/go/pkg/**"`. Los de un solo
componente, sin barra (`.npm`, `node_modules`, `.oh-my-zsh`), andan tal cual en
las dos.

### Por qué no alcanza con `rofi -show recursivebrowser`

Ese modo existe en rofi 2.0 y hasta abre con `xdg-open` por su cuenta, así que a
primera vista haría el trabajo sin script. El problema es que usa su propio
escáner y no tiene forma de excluir nada: lista las decenas de miles de archivos
de caché y sepulta bajo ellos a los que uno busca. Con `fd` esos se filtran y el
menú se genera igual en menos de 100 ms.

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

## Mantenimiento

### Qué se está comiendo la RAM: `ram-top`

Las aplicaciones que más memoria usan, **sumadas por aplicación**. Es lo que htop y
btop no hacen: un navegador o una app de Electron no son un proceso sino veinte, y
ahí aparecen como una lista de `firefox` sueltos sin un total.

```sh
ram-top                 las 10 que más usan
ram-top -i              interactivo: recorrer con las flechas y ver el detalle
ram-top -n 20           cambiar cuántas
ram-top -t              con el detalle de procesos de cada una
ram-top firefox         sólo esa, con el detalle
ram-top --rss           medir con RSS, para ver la diferencia
```

**`ram-top -i` es la forma cómoda de mirarlo.** Abre la lista en fzf y, a medida que
te movés con las flechas, el panel muestra los procesos de la aplicación que tenés
encima. Los números se recalculan en cada movimiento, así que ves el estado actual y
no una foto de cuando arrancó; `Ctrl-R` relee la lista entera.

Son **dos vistas**, y se navega entre ellas sin perder la de arriba:

| Tecla | En la lista de aplicaciones | En la lista de procesos |
|---|---|---|
| `Enter` | Entra a los procesos de esa aplicación | Sale dejando el detalle de ese proceso impreso |
| `Escape` | Sale | **Vuelve** a las aplicaciones |
| `Ctrl-O` | Oculta el panel (la lista queda a pantalla completa) | ídem |
| `Ctrl-R` | Relee | ídem |

La segunda vista da, por proceso, lo que no se ve en ningún otro lado: cuánta memoria
es **privada** —la que se libera de verdad si ese proceso muere— contra cuánta
comparte con sus hermanos, el pico de RSS desde que arrancó, los hilos y la línea de
comandos completa.

**En pantallas angostas el panel se pasa solo abajo**, para que la lista conserve el
ancho completo y no se le coman las barras. Lo decide fzf comparando el ancho que le
tocaría al panel contra un mínimo, así que se reacomoda al **redimensionar** la
terminal y no sólo al arrancar.

**Mide con PSS, y esa es la parte que importa.** Sumar el RSS de los procesos de una
aplicación cuenta la memoria compartida una vez por proceso, y da un número muy
inflado: en este equipo, los procesos de Firefox suman 4.9 GiB de RSS contra 2.7 GiB
reales. PSS reparte cada página compartida entre los que la usan, así que el total de
un grupo sí significa algo — cuánta RAM se liberaría cerrando esa aplicación.
`ram-top --rss` muestra las dos cosas para comparar.

El detalle nombra el **rol** de cada proceso cuando puede (`renderer`, `gpu-process`,
`utility: network`), que es lo que distingue siete procesos de Electron llamados todos
igual. El `*` marca el proceso principal.

```
obsidian        358 MiB    1.1%     7  ████████████
    * 98097   obsidian                 116 MiB
      98156   renderer                  98 MiB
      98148   gpu-process               91 MiB
      98152   utility: network          27 MiB
```

Agrupa subiendo por el árbol de procesos, no por cgroup: bajo Hyprland **todo cae en
la misma `session-c1.scope`**, así que el cgroup no distingue una aplicación de otra.
Los shells cortan la cadena, de modo que lo que arranques desde la terminal figura con
su propio nombre y no sumado a `ghostty`.

Los procesos de otros usuarios (demonios de root) quedan afuera: su memoria no es
legible sin permisos. El pie del informe dice cuántos, para que el total no parezca
completo cuando no lo es.

> `ram-top` vive en `bin_configs/`: hace falta `bash ~/config_files/scripts/link-bins.sh`
> (ver [Scripts propios](#scripts-propios-link-binssh)).

### Paquetes huérfanos: `clean-orphans`

Lista los paquetes **huérfanos** — instalados como dependencia de algo que ya no
está — con el tamaño de cada uno y el total, pide confirmación y los elimina.

```sh
clean-orphans
```

Los huérfanos aparecen solos con el uso normal: desinstalar un programa deja
atrás sus dependencias, y los builds de AUR dejan compiladores que ya no hacen
falta (al desinstalar nmrs quedaron `rust` y `go`: 1.7 GB). Correrlo cada tanto
recupera ese disco.

Borra **en rondas** hasta que no quede ninguno, porque eliminar un huérfano
puede dejar huérfanos nuevos. Usa `pacman -Qdt` (y no `-Qdtt`) a propósito: la
variante con doble `t` incluye dependencias *opcionales*, y borrar esas rompe
funcionalidades en silencio.

Para mirar sin tocar nada:

```sh
pacman -Qdt      # huérfanos actuales
pacman -Qm       # paquetes foráneos (AUR): no son huérfanos, sólo otro origen
```

### Poner al día un equipo rezagado: `update-since-*.sh`

`archdesktopinstall.sh` es para instalar de cero. Cuando un equipo **ya
instalado** se queda atrás de un cambio que necesita más que un `git pull`
—paquetes nuevos, symlinks que se movieron, procesos que hay que reiniciar—
ese salto se escribe como un script en `scripts/`:

```sh
bash ~/config_files/scripts/update-since-comprimidos.sh   # comprimidos en Thunar, módulo de swap, tooltip de rclone
bash ~/config_files/scripts/update-since-zoom.sh          # zoom + VA-API, y los launchers que se movieron a launchers/
```

Todos son idempotentes: reejecutarlos en un equipo al día no cambia nada. Cada
uno arranca con un `git pull --ff-only` que **se saltea solo** si hay cambios sin
commitear, para no pisarte trabajo local.

Lo que un `git pull` no puede hacer solo, y por eso existen estos scripts:
instalar paquetes, y **sacudir los procesos que ya están corriendo con la
versión vieja en memoria**. Thunar sigue de demonio en segundo plano aunque
cierres todas las ventanas y carga sus plugins sólo al arrancar (`thunar -q`);
waybar tiene su config en memoria (`SIGUSR2`); y el demonio de rclone-sync es un
script de bash, que bash lee *a medida* que lo ejecuta — o sea que un `git pull`
le cambia el archivo abajo de los pies y hay que reiniciarlo sí o sí.

### Scripts propios: `link-bins.sh`

Los ejecutables del repo (`hyprshutdown`, `add-printer`, `clean-orphans`,
`pick-window`, `find-file`, `sort-workspaces`, el wrapper `dbeaver`) viven en
`bin_configs/` y se usan desde el
PATH gracias a un symlink en `/usr/local/bin`. El instalador los crea, pero al
**sumar un script nuevo** en una máquina ya instalada hay que reponerlos:

```sh
bash ~/config_files/scripts/link-bins.sh
```

Enlaza todo lo ejecutable de `bin_configs/` y es idempotente, así que repone
sólo lo que falte. Omite a propósito `power-profile-sync`, que se instala
*copiado* y no enlazado (ver [Perfil de energía](#perfil-de-energía)).

Si una terminal ya abierta sigue sin encontrar el comando nuevo, es el caché de
zsh: `rehash`.

## Waybar: clics

| Módulo | Clic izquierdo abre |
|---|---|
| Workspaces | Va a ese workspace |
| Reloj | Google Calendar (chromium en modo app) |
| Volumen | wiremix, en una terminal |
| Batería | — (`format-alt`: alterna a tiempo restante) |
| Perfil de energía | Cicla entre performance / balanced / power-saver |
| Bluetooth | bluetui, en una terminal |
| Sincronización con Drive | El menú de `rclone-sync`, en una terminal (clic derecho: el log) |
| Red | nmtui, en una terminal |
| CPU | btop, en una terminal |
| Swap | htop, en una terminal |
| Memoria | htop, en una terminal |
| Disco | btop, en una terminal |
| Idioma del teclado | Cambia al siguiente layout |

## Swap en la barra

Entre CPU y memoria hay un módulo propio (`dotconfig/waybar/scripts/swap.sh`) que
muestra el porcentaje de swap ocupado con el icono ⇄. Es un script y no el módulo
estándar de waybar porque **ese porcentaje solo no significa nada**: depende de qué
haya debajo, y eso cambia de un equipo a otro.

| Debajo hay | Qué es | Un 90% significa |
|---|---|---|
| **zram** | Un disco comprimido en RAM. Los GiB que anuncia son virtuales: 4 GiB de zram llenos pueden ocupar 900 MiB reales | Normal. No se tocó el disco |
| **Partición** | Swap de verdad, en el disco | El equipo está arrastrándose |
| **Archivo** | Igual que la partición, pero sobre el filesystem | Lo mismo |
| **zswap** | No es un swap: es una caché comprimida en RAM **delante** del swap real. No aparece en `/proc/swaps` ni suma tamaño | — (se informa aparte) |

Por eso el tooltip dice la configuración real y no sólo el número: tipo de cada
dispositivo, tamaño, cuánto está en uso, la prioridad, y con zram además cuánta RAM
está ocupando de verdad y el ratio de compresión que está logrando. Si hay varios
swaps a la vez, el tooltip los lista todos y el porcentaje de la barra es el
agregado.

Los umbrales de color se ajustan a eso: con swap en disco el módulo avisa (texto
blanco) al 50% y se pone coral al 80%; si el swap es sólo zram, recién al 70% y al
90%. Sin swap configurado el módulo no aparece.

Los datos salen de `/proc/swaps` y `/sys`, sin `zramctl` y sin root. La ocupación de
zswap es la única excepción: sus contadores viven en debugfs y sólo los lee root, así
que de zswap se informa la configuración (activo, compresor) y no cuánto tiene
guardado.

## Disco en la barra

El último módulo de la derecha (`dotconfig/waybar/scripts/disk.sh`) muestra cuánto
hay ocupado y cuánto entra en el disco donde vive `/`: **`17/953G`**. La unidad va
una sola vez, al final, para que el par se lea como una fracción.

Es un script y no el módulo `disk` estándar de waybar porque **ése mira un único
path**, escrito a mano en el config (`"path": "/"`). En un equipo con `/home` o
`/var` en particiones aparte muestra una y calla las otras — y la que se llena es
siempre la otra. Como `config.jsonc` es el mismo archivo en todas las máquinas y el
particionado no lo es, el script descubre en cada refresco lo que hay montado: no
hay nada que configurar por equipo.

**El tooltip lista todos los sistemas de archivos montados**, uno por dispositivo:
tipo, tamaño, ocupado, libre y en qué puntos está montado.

| Detalle | Por qué |
|---|---|
| Un filesystem se cuenta **una vez**, no una por punto de montaje | En btrfs `/`, `/home` y `/var/log` son subvolúmenes de la **misma** partición y comparten los mismos GiB. Listarlos por separado sumaría discos imaginarios. Los bind mounts, igual |
| El **swap no aparece**, ni con partición propia | El swap no se monta como filesystem, así que no está en la lista de la que sale esto. No hay forma de que se duplique con el módulo de al lado. Un swap*file* sí ocupa lugar en su filesystem y sí se cuenta: ese espacio no lo tenés |
| Sin tmpfs, `/proc`, `/sys`, cgroups, ni los loops de snap/appimage | Son RAM o inventos del kernel, no disco. Los squashfs además están siempre al 100% y llenarían el tooltip de ruido |
| Los externos van al final, marcados `(removable)`; los de red, `(network)` | Son visitas. Y un disco giratorio se marca `(HDD)`: explica por qué una carpeta abre lento |

El porcentaje se calcula `usado / (usado + disponible)`, igual que `df`, y no contra
el tamaño total. La diferencia son los bloques reservados para root — en ext4, el 5%
del disco: contra el total, un filesystem que ya **no** admite escrituras marcaría un
tranquilísimo 95% justo cuando dejó de andar.

Los colores avisan (texto blanco) al 80% y se ponen coral al 90%, pero **miran el
filesystem interno más lleno, no el de la barra**: en un equipo con `/home` aparte,
el que se llena es justamente el que no se ve. Cuando el que manda el color no es
`/`, el tooltip lo dice con nombre y apellido — si no, sería un módulo rojo mostrando
un 12%. Los extraíbles y los de red nunca pintan: un pendrive al 99% es un pendrive
lleno, no una alarma, y desenchufarlo no debería apagar un aviso.

Todo sale de `findmnt` (viene en util-linux) y de `/sys`, sin root. El refresco es
cada 5 minutos: el disco no cambia de tamaño en un minuto y, a diferencia de la RAM,
no hay nada que mirar en tiempo real.

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

## Archivos comprimidos

Se manejan desde el **clic derecho en Thunar**, sin abrir ninguna aplicación:

| Opción del menú | Qué hace |
|---|---|
| **Extraer aquí** | Descomprime en la carpeta donde está el archivo |
| **Extraer en…** | Pregunta la carpeta destino |
| **Comprimir…** | Arma un archivo con lo que tengas seleccionado |

Son tres piezas y hacen falta las tres: `thunar-archive-plugin` pone las opciones
en el menú, `xarchiver` las ejecuta, y los descompresores de línea de comandos
son los que realmente abren cada formato. Si falta el binario de un formato la
opción igual aparece, pero no extrae nada y **xarchiver no dice qué le falta**.

El pegamento entre las dos primeras es
`/usr/lib/xfce4/thunar-archive-plugin/xarchiver.tap`, y lo aporta el paquete
**xarchiver**, no el plugin: el plugin sólo trae los `.tap` de file-roller, ark y
engrampa. Es la razón de que instalar el plugin solo no agregue nada al menú.

**Extraer aquí** no desparrama: si el archivo no viene ya envuelto en una
carpeta, xarchiver le crea una (`--ensure-directory`). No existe el caso de
quedar con 200 archivos sueltos encima de la carpeta de descargas.

Con lo que instala `archdesktopinstall.sh` quedan cubiertos zip, rar, 7z, tar y
todas sus variantes (`.tar.gz`, `.tar.xz`, `.tar.zst`, `.tar.bz2`), más cab, iso
y rpm de yapa. Doble clic sobre un comprimido lo abre en xarchiver para ver el
contenido sin extraerlo.

Dos cosas que sorprenden:

- **`.rar` sólo se puede extraer, no crear.** El paquete `unrar` es el
  descompresor; comprimir en rar necesita el binario propietario `rar`, que está
  en AUR y no se instala. Para comprimir, usá zip o 7z.
- Si instalás el plugin en un equipo donde Thunar ya está corriendo, no aparece
  nada en el menú hasta reiniciarlo: `thunar -q`.

¿Un formato raro que no abre (lzop, lzip, arj, lha, deb)? `pacman -Si xarchiver`
lista en *Optional Deps* qué paquete instalar para cada uno.

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

#### Si la pantalla queda negra

Apretá **`SUPER + D`**. Se puede pulsar a ciegas: aunque no haya señal de video,
el teclado le sigue llegando a Hyprland.

Hace falta porque un apagado de pantalla que **no** haya disparado hypridle queda
*pegado*. El `on-resume` de hypridle solo corre para el listener que efectivamente
hizo timeout, así que si el `dpms off` vino de otro lado — un `hyprctl` a mano, un
script, una prueba — mover el mouse no enciende nada, y sin este atajo la única
salida es reiniciar el equipo.

Desde una TTY (`Ctrl + Alt + F2`) el equivalente es:

```sh
hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
```

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
| Barra: módulo de swap | `dotconfig/waybar/scripts/swap.sh` (ver [Swap en la barra](#swap-en-la-barra)) |
| Barra: módulo de disco | `dotconfig/waybar/scripts/disk.sh` (ver [Disco en la barra](#disco-en-la-barra)) |
| Notificaciones | `dotconfig/mako/config` |
| Lanzador | `dotconfig/rofi/config.rasi` y `dark.rasi` |
| Terminal | `dotconfig/ghostty/config.ghostty` |
| fzf, función `imgs`, `PATH` y hook de direnv | `zshrc.local` |
| Asociaciones de archivos | `mimeapps.list` |
| Ignore global de git | `dotconfig/git/ignore` |
| Teams: la X cierra la app | `launchers/teams-for-linux.config.json` (ver [`../linux/teams.md`](../linux/teams.md)) |
| Teams: arranque en Wayland | `applications/teams-for-linux.desktop` |
| Spotify: arranque en Wayland | `launchers/spotify-launcher.conf` (ver [`../linux/spotify.md`](../linux/spotify.md)) |
| Zoom: arranque en Wayland | `~/.config/zoomus.conf` (no versionado, ver [`../linux/zoom.md`](../linux/zoom.md)) |
| Perfiles de energía | `etc/systemd/system/`, `etc/udev/rules.d/`, `etc/polkit-1/rules.d/`, `bin_configs/power-profile-sync` |
| Asistente de impresión | `bin_configs/add-printer` (enlazado en `/usr/local/bin`) |
| Limpieza de huérfanos | `bin_configs/clean-orphans` (enlazado en `/usr/local/bin`) |
| Selector de ventanas | `bin_configs/pick-window` (enlazado en `/usr/local/bin`) |
| Buscador de archivos | `bin_configs/find-file` (enlazado en `/usr/local/bin`) |
| Renumerar workspaces | `bin_configs/sort-workspaces` (enlazado en `/usr/local/bin`, ver [Renumerar](#renumerar-los-workspaces-quedan-1n-en-orden-visual)) |
| Enlazar los scripts propios | `scripts/link-bins.sh` |
| Instalación completa | `archdesktopinstall.sh` |

Todo lo de `dotconfig/` se enlaza con symlinks a `~/.config/`; lo de `etc/` se
**copia** a `/etc` (lo lee root o udev antes de que se monte `/home`).
`applications/` se enlaza a `~/.local/share/applications/`, que tiene prioridad
sobre `/usr/share/applications` y así sobrevive a los upgrades del paquete.

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
