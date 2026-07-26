# DBeaver en Wayland

Qué se instala, por qué **no** lleva configuración de Wayland, y las trampas en
las que es fácil caer si algún día algo se ve mal.

- [Resumen](#resumen)
- [Qué se verificó](#qué-se-verificó)
- [Lo que NO hay que hacer](#lo-que-no-hay-que-hacer)
- [La versión de Java](#la-versión-de-java)
- [Memoria: el heap a 4 GB](#memoria-el-heap-a-4-gb)
- [Diagnóstico](#diagnóstico)

## Resumen

DBeaver 26.1.3 (SWT 3.134 / GTK3) **funciona en Wayland nativo sin ninguna
variable de entorno ni regla de ventana**. No hay nada que configurar: el
paquete `dbeaver` y `jre21-openjdk` de la sección 5 alcanzan.

Este documento existe para dejar constancia de *por qué* no hay configuración,
porque la receta que circula por internet (forzar XWayland) acá empeora las
cosas.

## Qué se verificó

En este equipo (Hyprland 0.56, eDP-1 2560x1600 a **escala 2**):

| Comprobación | Cómo se midió | Resultado |
|---|---|---|
| Backend | `hyprctl -j clients` | `xwayland=false` → **Wayland nativo**, sin tocar `GDK_BACKEND` |
| HiDPI | `grim` sobre la ventana | ventana lógica de 1266x740 → PNG de **2532x1480**, o sea render a 2x real, no upscaling |
| Menús desplegables | captura con el menú abierto | posicionados correctamente (es el fallo clásico de SWT en Wayland) |
| Diálogos | abrir uno y mirar `hyprctl` | salen con `float=true`; Hyprland los flota solo, **no hace falta `window_rule`** |
| Arranque | log del lanzador | limpio salvo un `Gdk-CRITICAL gdk_threads_set_lock_functions` inofensivo que SWT tira siempre |

## Lo que NO hay que hacer

**No pongas `GDK_BACKEND=x11`.** Es el consejo que aparece en foros viejos, de
cuando SWT no manejaba bien Wayland. Hoy sobra, y acá es contraproducente:
`xwayland:force_zero_scaling` no está activado en `hyprland.lua`, así que
Hyprland renderiza las apps de XWayland a 1x y las escala a 2x — texto borroso.
En Wayland nativo el render es a 2x real.

Tampoco hacen falta `GDK_SCALE`, `_JAVA_AWT_WM_NONREPARENTING=1` (eso es para
apps AWT/Swing bajo X11; DBeaver es SWT) ni ninguna `window_rule`.

Lo único que ya viene resuelto de fábrica es `GTK_OVERLAY_SCROLLING=0`, que lo
exporta el propio `/usr/bin/dbeaver` del paquete de Arch para esquivar un bug
viejo de las barras de scroll de GTK+ en Eclipse.

## La versión de Java

El paquete pide `java-runtime>=21`. Se instala **`jre21-openjdk`** y no el
`jre-openjdk` suelto (que hoy es la 26) porque las builds oficiales de DBeaver
embeben un JRE 21: es la versión contra la que upstream lo prueba.

```bash
archlinux-java status     # ver cuál está activa
```

Si algún día instalás otro JDK y DBeaver empieza a fallar raro, revisá que la
default siga siendo la 21.

## Memoria: el heap a 4 GB

`/usr/lib/dbeaver/dbeaver.ini` viene con `-Xmx1024m`. Para result sets grandes
o exportaciones eso queda corto y DBeaver empieza a tirar `OutOfMemoryError`.

**No edites ese `.ini`**: no está en el array `backup` del paquete (`pacman -Qii
dbeaver` → `Backup Files: None`), así que cada actualización lo pisa sin avisar
ni dejar un `.pacnew`.

Tampoco sirve `dbeaver -vmargs -Xmx4g`: en los lanzadores de Eclipse los
`-vmargs` de la línea de comandos **reemplazan** a los del `.ini`, y ahí se
perderían los ~25 `--add-opens` que DBeaver necesita para arrancar.

La solución es el wrapper **`bin_configs/dbeaver`**, que la sección 9 del script
enlaza en `/usr/local/bin/dbeaver`:

```sh
export _JAVA_OPTIONS=-Xmx4g
exec /usr/bin/dbeaver "$@"
```

Tres detalles que explican por qué está armado así:

- **Por qué `/usr/local/bin`.** En el PATH va antes que `/usr/bin`, así que tapa
  al binario del paquete. La entrada `.desktop` de DBeaver dice `Exec=dbeaver`
  (sin ruta), o sea que se resuelve por PATH: el wrapper aplica igual desde rofi
  que desde la terminal. `~/.local/bin` **no** serviría: ahí lo mete
  `zshrc.local`, o sea sólo en shells interactivas, y las apps que lanza rofi
  las spawnea Hyprland, que no pasa por zsh.
- **Por qué llama a `/usr/bin/dbeaver` por ruta absoluta.** El wrapper se llama
  igual que el original; sin la ruta absoluta se llamaría a sí mismo en bucle.
  Delegar en `/usr/bin/dbeaver` (en vez de saltar directo a
  `/usr/lib/dbeaver/dbeaver`) mantiene el `GTK_OVERLAY_SCROLLING=0` que exporta
  el lanzador de Arch, y hace que cualquier arreglo futuro del paquete se herede
  solo.
- **Por qué `_JAVA_OPTIONS` y no `JAVA_TOOL_OPTIONS`.** Puro orden de precedencia
  de la JVM: `JAVA_TOOL_OPTIONS` se procesa *antes* que la línea de comandos, así
  que el `-Xmx1024m` del `.ini` la pisaría; `_JAVA_OPTIONS` se procesa *después*
  y gana. Efecto colateral: la JVM imprime `Picked up _JAVA_OPTIONS: -Xmx4g` en
  stderr, inofensivo.

Verificado en el log de arranque: `Memory available 80Mb/4096Mb` (antes decía
`134Mb/1024Mb`). También se puede mirar desde **Help → About → Installation
Details**.

## Diagnóstico

```bash
hyprctl -j clients | jq -r '.[] | select(.class=="DBeaver")'   # backend, tamaño, floating
java -version                                                   # runtime activo
```

El workspace y los logs viven en `~/.local/share/DBeaverData/workspace6/`
(`.metadata/dbeaver-debug.log` para los errores).

Si algo se ve borroso, lo primero es confirmar `xwayland=false`. Si diera
`true`, algo está forzando XWayland (una variable de entorno en `hyprland.lua`
o en el shell), y eso es el problema, no la solución.
