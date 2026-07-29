# Teams for Linux: la X y la bandeja que no existe

Por qué la ventana "se moría" sin dejar rastro, y por qué el arreglo es una línea
de `config.json` y no reinstalar nada.

- [Resumen](#resumen)
- [El diagnóstico](#el-diagnóstico)
- [Por qué no había icono de bandeja](#por-qué-no-había-icono-de-bandeja)
- [El segundo síntoma: "Waiting for network..."](#el-segundo-síntoma-waiting-for-network)
- [Cómo rescatar una ventana ya escondida](#cómo-rescatar-una-ventana-ya-escondida)
- [Alternativas descartadas](#alternativas-descartadas)
- [Diagnóstico](#diagnóstico)
- [El .desktop y el flag de Wayland](#el-desktop-y-el-flag-de-wayland)

## Resumen

`teams-for-linux` viene con `closeAppOnCross: false` por defecto: al pulsar la **X**
la ventana **no se cierra, se esconde a la bandeja del sistema**. Esta barra
(`dotconfig/waybar/config.jsonc`) **no tiene módulo `tray`**, así que la ventana se
esconde a una bandeja que no existe: desaparece de Hyprland, no hay icono en el que
hacer clic, y los ~8 procesos de Electron siguen vivos consumiendo ~250 MB. Parece
que la app se murió.

El arreglo vive en **`teams-for-linux.config.json`** (raíz del repo, la sección 9 del
instalador lo enlaza a `~/.config/teams-for-linux/config.json`):

```json
{
  "closeAppOnCross": true
}
```

Con eso la X termina la app de verdad. Toma efecto **reiniciando** la app
(`applyMode: "restart"` en las opciones del upstream), no en caliente.

Dos detalles del archivo:

- Se carga con `require()`, así que es **JSON estricto: no acepta comentarios**. Por
  eso el porqué vive en este doc y no en el archivo.
- Se enlaza **archivo por archivo**, no el directorio. `~/.config/teams-for-linux`
  es además el `user-data-dir` de Electron (`Cache`, `Cookies`, `Session Storage`):
  enlazar el directorio entero metería la sesión y los cachés al repo.

## El diagnóstico

Lo que confundía es que **no había nada roto**. Con la ventana ya desaparecida:

| Comprobación | Resultado |
|---|---|
| `pgrep -af teams-for-linux` | 8 procesos vivos, `Sl` (sleeping), 0% CPU |
| `hyprctl clients` | **ninguna** ventana con class `teams-for-linux` |
| `ls Crashpad/` | sólo `client_id` — **cero crash dumps** |
| `journalctl` del día | cero líneas de teams: ni crash, ni OOM kill, ni señal |
| `/var/log/pacman.log` | 2.13.0 instalado el 27/07, sin upgrade el día del incidente |

Procesos vivos + ventana inexistente + cero errores = la app no se cayó, **se
escondió**. Los tres defaults que lo explican, en `app/config/options.js` del
`app.asar`:

| Opción | Default | Efecto |
|---|---|---|
| `closeAppOnCross` | `false` | la X no cierra |
| `minimizeOnClose` | `false` | …y tampoco minimiza: **esconde a la bandeja** |
| `trayIconEnabled` | `true` | intenta crear el icono… que nadie muestra |

## Por qué no había icono de bandeja

La bandeja en Wayland es el protocolo D-Bus **StatusNotifierItem**: la app publica
un item y la barra tiene que estar corriendo un *watcher* que lo recoja. Acá no hay
ninguno:

```console
$ busctl --user call org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.freedesktop.DBus.Properties Get ss \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
Call failed: The name is not activatable
```

Ese `not activatable` es el punto: el nombre no está ni registrado ni es
auto-arrancable, o sea **nadie provee bandeja en este equipo**. Teams publica su
icono al vacío.

No es que falte soporte: waybar 0.15.0 de Arch **sí** trae el módulo (depende de
`libdbusmenu-gtk3`), simplemente no está en `modules-right`. Agregarlo es la otra
salida posible — ver [Alternativas descartadas](#alternativas-descartadas).

## El segundo síntoma: "Waiting for network..."

Al recuperar la ventana escondida, apareció con el título **`Waiting for network...`**
y se quedó ahí indefinidamente, con la red perfecta (`curl https://teams.microsoft.com`
→ 302 en 240 ms, DNS en 70 ms).

Es el bug upstream [#2611](https://github.com/IsmaelMartinez/teams-for-linux/issues/2611),
descrito en el propio código (`app/connectionManager/index.js`): un socket que quedó
colgado deja el chequeo de conectividad pendiente para siempre, el `finally` nunca
limpia el guard `isRefreshing`, y **todos los reintentos posteriores se saltean**. La
app se queda en ese título hasta que la matas.

Ojo: la instancia colgada **ya era 2.13.0**, la versión que trae el `PROBE_TIMEOUT_MS`
de 5 s que supuestamente lo arregla. Tras 23 h de uptime seguía colgándose, así que el
parche no cubre todos los casos. Único arreglo: reiniciar la app.

Esto es el bonus de `closeAppOnCross: true`: cada X es un cierre real, y el próximo
arranque parte con estado de red limpio. Una instancia que vive semanas escondida es
justo la que acumula este bug.

## Cómo rescatar una ventana ya escondida

Sin bandeja y sin haber aplicado el arreglo todavía, no hace falta matar nada:
**relanzar el binario**. Electron usa un *single instance lock*, así que la segunda
instancia no abre otra ventana — le pide a la primera que muestre la suya y se va:

```console
$ /opt/teams-for-linux/teams-for-linux --ozone-platform=wayland
12:22:27.183 › App already running
```

Ese `App already running` es la confirmación de que se recicló la instancia existente
(mismo PID en `hyprctl clients`, no una duplicada).

Si además quedó colgada en `Waiting for network...`, hay que reiniciarla de verdad. Un
detalle: **el proceso main ignora `SIGTERM`** — `pkill` se lleva los hijos y el main
sobrevive respawneando su servicio de red. Hay que ir con `kill -9` al PID del main:

```bash
kill -9 $(pgrep -f 'teams-for-linux --ozone-platform=wayland$')
```

Y otro detalle de `pkill`: un `pkill -f /opt/teams-for-linux/teams-for-linux` mata
**también la shell que lo ejecuta**, porque su propia línea de comandos contiene el
patrón. Mejor filtrar por PID.

La sesión sobrevive al reinicio: las cookies están en `~/.config/teams-for-linux`, no
hay que volver a loguearse.

## Alternativas descartadas

- **Agregar el módulo `tray` a waybar.** Es el arreglo más general (serviría para
  cualquier app de bandeja, y da clic derecho → Quit), pero cambia el aspecto de la
  barra, que está afinada a mano en alto y espaciado. Queda disponible si algún día
  hace falta para otra app.
- **`minimizeOnClose: true`.** La X minimiza en vez de esconder, así la ventana sigue
  existiendo en Hyprland y se recupera desde el workspace. Deja la app corriendo, o
  sea que no ayuda contra el #2611.
- **`trayIconEnabled: false`.** Complemento coherente (deja de publicar un icono que
  nadie muestra), pero es cosmético: no cambia el comportamiento de la X, que es lo
  que causaba el problema. Se deja el default por si algún día se suma la bandeja.

## Diagnóstico

Si la ventana de Teams vuelve a desaparecer:

```bash
# ¿Sigue el proceso vivo pero sin ventana? -> está escondido, no muerto
pgrep -af 'opt/teams-for-linux'
hyprctl clients -j | grep -i teams

# ¿Hay alguien sirviendo bandeja del sistema?
busctl --user list | grep -i StatusNotifier

# ¿Se cayó de verdad? (vacío salvo client_id = no hubo crash)
ls ~/.config/teams-for-linux/Crashpad/

# ¿El config.json está tomando efecto? Arrancar a mano y mirar la primera línea:
#   "Using user configuration"                        -> OK
#   "No config file found ... using default values"    -> el symlink no está
/opt/teams-for-linux/teams-for-linux --ozone-platform=wayland
```

El binario se lanza con `--ozone-platform=wayland` (Wayland nativo, mismo motivo que
[Spotify](./spotify.md): a escala 2x XWayland se ve borroso). Ese flag vive en el
`.desktop` override — ver la sección siguiente.

## El .desktop y el flag de Wayland

El paquete instala `/usr/share/applications/teams-for-linux.desktop` con
`--ozone-platform=x11`. El override vive en **`applications/teams-for-linux.desktop`**
(raíz del repo; la sección 9 del instalador lo enlaza a
`~/.local/share/applications/teams-for-linux.desktop`, que tiene prioridad sobre
`/usr/share` cuando el archivo se llama igual, y así sobrevive a los upgrades).

Es una copia completa del `.desktop` del paquete con **una sola línea cambiada**:

```ini
Exec=/opt/teams-for-linux/teams-for-linux --ozone-platform=wayland %U
```

Eso tiene una consecuencia que hay que tener presente: al ser copia completa, también
**congela los demás campos** (`Icon`, `StartupWMClass`, `MimeType`, `Categories`). Si
un upgrade de teams-for-linux cambiara alguno, nuestra copia lo pisaría en silencio.
Por eso el instalador incluye un chequeo que compara ambos archivos **ignorando el
`Exec`** y avisa si aparece cualquier otra diferencia:

```console
!! OJO: el .desktop del paquete teams-for-linux cambió más allá del Exec.
```

Si ese aviso aparece, hay que mirar el `diff` y trasladar a mano el cambio del paquete
a la copia del repo.

El instalador corre además `update-desktop-database` sobre
`~/.local/share/applications`: el entry declara `x-scheme-handler/msteams`, o sea que
es el que abre los links `msteams:` (los "Join meeting" de Outlook). Sin refrescar el
`mimeinfo.cache`, el lanzador funcionaría pero `xdg-open` no sabría qué app abre ese
esquema. Para comprobarlo:

```console
$ xdg-mime query default x-scheme-handler/msteams
teams-for-linux.desktop
```

`desktop-file-validate` sobre el archivo tira un *hint* por tener más de una categoría
principal en `Categories` (`Chat;Network;Office;`). Viene tal cual del paquete y es sólo
un hint, no un error: se deja igual para que el `diff` contra el del paquete siga siendo
de una línea.
