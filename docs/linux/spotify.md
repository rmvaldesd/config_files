# Spotify en Wayland

Por qué se veía borroso con el monitor a escala 2, y por qué el arreglo son dos
flags de línea de comandos y no una variable de entorno.

- [Resumen](#resumen)
- [El diagnóstico](#el-diagnóstico)
- [Por qué la variable de entorno no alcanza](#por-qué-la-variable-de-entorno-no-alcanza)
- [Lo que NO hay que hacer](#lo-que-no-hay-que-hacer)
- [Efecto secundario: cambia el class de la ventana](#efecto-secundario-cambia-el-class-de-la-ventana)
- [Diagnóstico](#diagnóstico)

## Resumen

El cliente oficial de Spotify (vía `spotify-launcher`) arrancaba en **XWayland**.
Con `eDP-1` a escala 2, Hyprland renderiza las apps de XWayland a 1x y las estira
a 2x: texto y carátulas borrosos.

El arreglo vive en **`spotify-launcher.conf`** (raíz del repo, la sección 9 del
instalador lo enlaza a `~/.config/spotify-launcher.conf`):

```ini
[spotify]
extra_arguments = ["--enable-features=UseOzonePlatform", "--ozone-platform=wayland"]
```

Con eso Spotify pasa a Wayland nativo, lee el scale del `wl_output` y rasteriza a
2x real. Los cambios toman efecto reiniciando Spotify, no hace falta relogear.

## El diagnóstico

En este equipo (Hyprland 0.56, eDP-1 2560x1600 a **escala 2**,
`spotify-launcher` 0.6.6):

| Comprobación | Antes | Después |
|---|---|---|
| Backend (`hyprctl -j clients`) | `xwayland: true` → render 1x estirado a 2x | `xwayland: false` → **Wayland nativo** |
| HiDPI (`grim` sobre la ventana) | — | ventana lógica de 629x756 → PNG de **1258x1512**, o sea 2x real |
| MPRIS (`playerctl -l`) | `spotify` | `spotify` — sigue igual, va por D-Bus |

La medición con `grim` es la que decide: si el PNG sale del mismo tamaño que la
ventana lógica, hay upscaling; si sale al doble, el render es nativo.

## Por qué la variable de entorno no alcanza

`hyprland.lua` ya exporta `ELECTRON_OZONE_PLATFORM_HINT=wayland`, y aun así
Spotify seguía en XWayland. No es que la variable falle: es que **no le aplica**.

Esa variable la lee el runtime de **Electron**. Spotify no es Electron — es
**CEF** (Chromium Embedded Framework) embebido en un binario propio, y CEF sólo
mira los *flags* de línea de comandos. De ahí que el arreglo tenga que entrar por
`extra_arguments` y no por el bloque de `hl.env` del `hyprland.lua`.

Mismo motivo por el que un `~/.config/spotify-flags.conf` tampoco sirve: ese
archivo lo lee el paquete `spotify` del AUR en su wrapper, no `spotify-launcher`.

## Lo que NO hay que hacer

**No uses `--force-device-scale-factor=2.0`.** Aparece comentado como sugerencia
en el propio `/etc/spotify-launcher.conf` y "funciona", pero clava la escala a 2
a mano: es la solución para quien se queda en XWayland. Enchufado a un monitor
externo a escala 1, Spotify saldría al doble de grande. En Wayland nativo la
escala la negocia el compositor y no hay nada que forzar.

**No edites `/etc/spotify-launcher.conf`.** El config de usuario en
`~/.config/spotify-launcher.conf` lo pisa entero, y así el ajuste queda versionado
en el repo en vez de en un archivo de sistema que no se respalda.

## Efecto secundario: cambia el class de la ventana

Al salir de XWayland cambia el identificador de la ventana:

| | class |
|---|---|
| XWayland (`WM_CLASS`) | `Spotify` |
| Wayland nativo (`app_id`) | `spotify` |

Hoy **no hay ninguna `window_rule` en `hyprland.lua` que matchee Spotify**, así
que el cambio es inofensivo. Pero si algún día agregás una (para mandarlo a un
workspace fijo, por ejemplo), tiene que decir `spotify` en minúscula. El
`.desktop` del paquete todavía declara `StartupWMClass=spotify`, que ya coincide.

## Diagnóstico

```bash
hyprctl -j clients | jq -r '.[] | select(.class|test("spotify";"i"))'   # backend y tamaño
playerctl -l                                                             # que MPRIS siga registrado
spotify-launcher -v --skip-update --no-exec                              # ver los flags que va a pasar
```

Para medir el render real, con Spotify abierto:

```bash
G=$(hyprctl -j clients | jq -r '.[] | select(.class=="spotify") | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
grim -g "$G" /tmp/spot.png && identify /tmp/spot.png
```

El PNG tiene que dar el doble que la geometría lógica. Si da igual, Spotify
volvió a XWayland: revisá que `~/.config/spotify-launcher.conf` siga siendo el
symlink al repo.
