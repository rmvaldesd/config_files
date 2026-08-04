# Aceleración de video por hardware (VA-API)

Por qué instalar `intel-media-driver` no alcanza para que Spotify, Teams for
Linux o Chromium decodifiquen/codifiquen video por GPU, y por qué los flags
tienen que entrar con nombres exactos.

- [Resumen](#resumen)
- [Por qué el driver solo no alcanza](#por-qué-el-driver-solo-no-alcanza)
- [Los flags, uno por uno](#los-flags-uno-por-uno)
- [Verificación de los nombres](#verificación-de-los-nombres)
- [Diagnóstico](#diagnóstico)

## Resumen

`archdesktopinstall.sh` instala `intel-media-driver` (el driver VA-API para
GPUs Intel modernas) y `libva-utils` (para diagnosticar con `vainfo`), pero eso
sólo pone el driver disponible en el sistema. Los navegadores basados en
Chromium/CEF/Electron traen la aceleración de video **apagada por default en
Linux** (a diferencia de ChromeOS): hay que pedirla explícitamente con flags de
línea de comandos.

Se aplica a los tres "chrome-based apps" que este repo ya lanza con flags
propios:

| App | Motor | Dónde van los flags |
|---|---|---|
| Spotify | CEF (Chrome 146) | `launchers/spotify-launcher.conf` |
| Teams for Linux | Electron (Chrome 148) | `applications/teams-for-linux.desktop` |
| Chromium (calendario de Waybar) | Chromium 151 del sistema | `dotconfig/waybar/config.jsonc`, módulo `clock.on-click` |

Los cuatro flags que se agregaron a los tres:

```
--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
```

## Por qué el driver solo no alcanza

`vainfo` ya confirma que el driver funciona a nivel de sistema:

```console
$ vainfo
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 26.2.4 ()
      VAProfileH264Main               :	VAEntrypointVLD
      VAProfileHEVCMain               :	VAEntrypointVLD
      VAProfileVP9Profile0            :	VAEntrypointVLD
      ...
```

Pero VA-API en Linux "no está soportado" desde el punto de vista de Chromium:
la decodificación/codificación acelerada vive detrás de un *feature flag*
apagado por default, porque Google no certifica la combinación driver/GPU como
sí lo hace en ChromeOS. Sin el flag, cualquiera de las tres apps sigue
decodificando por software (CPU) aunque `intel-media-driver` esté instalado y
`vainfo` funcione perfecto.

## Los flags, uno por uno

- **`--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder`**
  — Prende la decodificación (`...DecodeLinuxGL`, la variante que usa el path
  GL/EGL, el que corre bajo Ozone/Wayland) y la codificación acelerada por
  hardware. Van juntos en un solo `--enable-features` separado por comas: si
  Spotify/Teams/Chromium reciben el switch **repetido** (uno para
  `UseOzonePlatform` y otro aparte para estos), Chromium se queda sólo con la
  ÚLTIMA ocurrencia y descarta la primera entera. Por eso en
  `spotify-launcher.conf`, que ya traía `--enable-features=UseOzonePlatform`,
  el valor quedó como una sola lista:
  `UseOzonePlatform,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder`.
- **`--ignore-gpu-blocklist`** — Chromium mantiene una lista interna de
  combinaciones GPU/driver que desactiva preventivamente aunque el hardware
  funcione, para no romperle la sesión a alguien con un driver problemático.
  Esta GPU (Meteor Lake, driver `xe` del kernel) es reciente y bien soportada,
  así que el riesgo de que el blocklist tape algo genuinamente roto es bajo.
- **`--enable-gpu-rasterization`** — Rasteriza el contenido web (tiles) en la
  GPU en vez de la CPU. Mejora el uso de CPU en páginas con mucho scroll/video,
  independiente de la decodificación de video en sí.
- **`--enable-zero-copy`** — Evita la copia CPU→GPU de los buffers de rasterizado
  (encadena bien con `--enable-gpu-rasterization`). Ojo con el nombre: el switch
  real es `enable-zero-copy`, no `zero-copy` a secas — este último no existe y
  Chromium lo ignoraría en silencio.

Un flag que se evaluó y **no** se agregó: `--ozone-platform-hint=auto`. No
aparece como string en ninguno de los tres binarios (ver verificación abajo), y
además Spotify y Teams ya fuerzan `--ozone-platform=wayland` a secas (ver
[Spotify](./spotify.md) y [Teams for Linux](./teams.md)), que le ganaría a un
`-hint` igual si existiera.

## Verificación de los nombres

Antes de tocar los tres archivos se verificó contra el binario/librería real de
cada app -- no contra documentación genérica -- porque cada motor puede llevar
una versión de Chromium distinta y los nombres de *feature flags* cambian entre
versiones (el prefijo viejo `Vaapi*` fue reemplazado por `Accelerated*` hace
varias versiones de Chromium):

```console
$ strings -a /usr/lib/chromium/chromium | grep -E '^(Vaapi|Accelerated)Video(Decode|Encod)[A-Za-z]*$'
AcceleratedVideoDecodeLinuxGL
AcceleratedVideoDecodeLinuxZeroCopyGL
AcceleratedVideoDecoder
AcceleratedVideoEncoder
VaapiVideoDecoder
VaapiVideoEncodeAccelerator

$ strings -a .../teams-for-linux | grep -E '^Chrome/'
Chrome/148.0.7778.271 Electron/42.5.0

$ strings -a .../libcef.so | grep -E '^Chrome/'
Chrome/146.0.7680.179
```

Los tres coinciden en `AcceleratedVideoDecodeLinuxGL` / `AcceleratedVideoEncoder`
y en que `enable-zero-copy` existe pero `zero-copy` y `ozone-platform-hint` no.
Si en el futuro se actualiza alguna de las tres apps a una versión mucho más
nueva, vale la pena repetir este chequeo antes de asumir que los flags actuales
siguen siendo válidos.

## Diagnóstico

Para confirmar que quedó activo tras reiniciar la app, `chrome://gpu` (funciona
en Chromium, Spotify y Teams: los tres exponen las páginas internas de
Chromium/CEF/Electron) — buscar:

```
Video Decode: Hardware accelerated
Video Encode: Hardware accelerated
```

Si sale "Software only", el flag no se está aplicando: revisar que el archivo
correspondiente (`~/.config/spotify-launcher.conf`,
`~/.local/share/applications/teams-for-linux.desktop`,
`dotconfig/waybar/config.jsonc`) siga siendo el symlink al repo y no una copia
vieja.
