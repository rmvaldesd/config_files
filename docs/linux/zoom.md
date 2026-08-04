# Zoom en Wayland

Por qué se veía borroso con el monitor a escala 2, y por qué el arreglo vive en
un archivo de estado que Zoom reescribe solo — no en el `.desktop` ni en un flag
de línea de comandos, a diferencia de [Spotify](./spotify.md) y
[Teams for Linux](./teams.md).

- [Resumen](#resumen)
- [El diagnóstico](#el-diagnóstico)
- [Por qué zoomus.conf no se enlaza al repo](#por-qué-zoomusconf-no-se-enlaza-al-repo)
- [Diagnóstico](#diagnóstico)

## Resumen

El cliente oficial de Zoom (paquete `zoom` del AUR) arrancaba en **XWayland**.
Con `eDP-1` a escala 2, Hyprland renderiza las apps de XWayland a 1x y las
estira a 2x: texto y video borrosos — el mismo síntoma que Spotify y
Teams for Linux, pero con una causa distinta por debajo.

Zoom es **Qt6**, no Electron/CEF: trae sus propios plugins de
`Qt Wayland` (`/opt/zoom/Qt/plugins/platforms/libqwayland-egl.so`) y decide si
los usa leyendo la clave `xwayland` de `~/.config/zoomus.conf`, no un flag de
línea de comandos ni la variable `QT_QPA_PLATFORM`. Por defecto esa clave viene
en `true`, así que Zoom eligió XWayland aunque el sistema es Wayland nativo.

El arreglo es dejarla en `false`:

```ini
[General]
xwayland=false
```

El instalador (sección 9 de `archdesktopinstall.sh`) lo aplica solo, pero **no
como symlink** — ver el por qué [más abajo](#por-qué-zoomusconf-no-se-enlaza-al-repo).
Toma efecto reiniciando Zoom.

## El diagnóstico

`ZoomLauncher` (`/opt/zoom/ZoomLauncher`, el binario detrás de `/usr/bin/zoom`)
es el que decide el backend antes de arrancar el proceso pesado
(`/opt/zoom/zoom`). Un `strings` sobre ese binario expone las dos piezas que usa
para la decisión:

```console
$ strings /opt/zoom/ZoomLauncher | grep -i 'wayland\|qpa'
QT_QPA_PLATFORM
xwayland
```

Y el propio `~/.config/zoomus.conf` (JSON no es, es INI) confirma la clave:

```console
$ grep -A1 '^\[General\]' ~/.config/zoomus.conf | grep xwayland
xwayland=true
```

Que los plugins de Wayland estén instalados de fábrica es lo que hace que el
arreglo sea una línea de config y no un paquete adicional:

```console
$ find /opt/zoom/Qt/plugins -iname '*wayland*'
/opt/zoom/Qt/plugins/wayland-decoration-client
/opt/zoom/Qt/plugins/wayland-graphics-integration-client
/opt/zoom/Qt/plugins/wayland-shell-integration
/opt/zoom/Qt/plugins/platforms/libqwayland-egl.so
/opt/zoom/Qt/plugins/platforms/libqwayland-generic.so
```

Con `xwayland=false` y Zoom corriendo, el mismo chequeo de `grim` que se usa
para Spotify confirma el render nativo (ventana lógica ×2 = tamaño del PNG).

## Por qué zoomus.conf no se enlaza al repo

`spotify-launcher.conf` y `teams-for-linux/config.json` son archivos **estáticos**:
ninguna de las dos apps los reescribe, así que enlazarlos al repo (`ln -sfn`) es
seguro — lo que hay en el repo es lo que corre siempre.

`zoomus.conf` es distinto: es el **archivo de estado** de Zoom, y lo reescribe
entero cada vez que corre. Ya en este equipo trae, entre otras, `deviceID` (la
MAC de la máquina), `currentMeetingId` y `userEmailAddress`. Enlazarlo al repo
metería eso al control de versiones en la próxima reunión, y además Zoom
pisaría el contenido "versionado" en cada arranque — el symlink sobreviviría,
pero el contenido dejaría de ser el que decidiste poner.

Por eso el instalador no usa `ln -sfn` para este archivo: aplica el ajuste con
`sed` (o crea el archivo mínimo si todavía no existe, porque se genera recién
al primer arranque de Zoom) y deja que Zoom siga administrando el resto del
archivo. Es idempotente — si `xwayland` ya está en `false`, no toca nada.

## Diagnóstico

```bash
# ¿Qué backend eligió Zoom la última vez que arrancó?
grep '^xwayland' ~/.config/zoomus.conf

# ¿Con qué backend está corriendo la ventana ahora?
hyprctl -j clients | jq -r '.[] | select(.class|test("zoom";"i")) | "\(.class) xwayland=\(.xwayland)"'
```

Para medir el render real, con Zoom abierto (mismo método que en
[Spotify](./spotify.md#diagnóstico)):

```bash
G=$(hyprctl -j clients | jq -r '.[] | select(.class=="zoom") | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
grim -g "$G" /tmp/zoom.png && identify /tmp/zoom.png
```

El PNG tiene que dar el doble que la geometría lógica. Si da igual, Zoom volvió
a XWayland: revisá que `xwayland=false` siga puesto en `~/.config/zoomus.conf`
(Zoom lo puede pisar solo si se corrompe el archivo o se reinstala desde cero).
