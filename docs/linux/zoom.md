# Zoom en Wayland

Por qué se veía borroso con el monitor a escala 2, y por qué el arreglo vive en
un archivo de estado que Zoom reescribe solo — no en el `.desktop` ni en un flag
de línea de comandos, a diferencia de [Spotify](./spotify.md) y
[Teams for Linux](./teams.md).

- [Resumen](#resumen)
- [El diagnóstico](#el-diagnóstico)
- [Por qué zoomus.conf no se enlaza al repo](#por-qué-zoomusconf-no-se-enlaza-al-repo)
- [Por qué los flags de VA-API no aplican acá](#por-qué-los-flags-de-va-api-no-aplican-acá)
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

## Por qué los flags de VA-API no aplican acá

[Spotify](./spotify.md), [Teams for Linux](./teams.md) y Chromium reciben los
flags de VA-API (ver [docs/linux/vaapi.md](./vaapi.md)) porque los tres son un
proceso Chromium/CEF/Electron arrancado directamente desde un archivo que
controlamos (`extra_arguments`, `Exec=`, `on-click`). Zoom no encaja en ese
molde:

- `strings` sobre `zoom`, `ZoomLauncher` y `ZoomWebviewHost` (el proceso CEF que
  Zoom levanta aparte para el webview de SSO/sala de espera) no muestra
  NINGUNO de los switches `--enable-features`, `--ignore-gpu-blocklist`,
  `--enable-gpu-rasterization` ni `--enable-zero-copy`. El parser de argumentos
  de Zoom sólo reconoce su propio set (`--ipc-server`, `--no-dns`, `--path`,
  `--share`, etc.), así que aunque se los pasáramos, Zoom los ignoraría.
- El `ZoomWebviewHost` es un proceso *hijo* que Zoom decide cuándo y cómo
  lanzar; no hay `.desktop` ni launcher nuestro en el medio para inyectarle
  flags, a diferencia del `Exec=` de teams-for-linux.
- La aceleración de hardware para el video de la llamada en sí (no el webview)
  es un ajuste nativo de Zoom — "Use hardware acceleration for sending/
  receiving video" en Settings → Video → Advanced —, pero esa preferencia vive
  en `~/.zoom/data/zoomus.enc.v2.db`, que está **cifrado**. A diferencia de
  `xwayland` en `zoomus.conf` (texto plano, ajustable con `sed`), esta clave no
  se puede automatizar desde el instalador: hay que activarla a mano dentro de
  la app, una sola vez.
- De paso: `zoomus.conf` ya trae `enableCefGpu=false`, pero esa clave sólo
  gobierna el GPU del webview CEF auxiliar, no la ruta de video de la reunión —
  no es un sustituto de la casilla de Settings.

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
