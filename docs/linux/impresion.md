# Impresión wifi (CUPS + Avahi)

Cómo queda montada la impresión en este equipo, qué instala el script y cómo
diagnosticar cuando la impresora no aparece.

- [Cómo funciona](#cómo-funciona)
- [Qué instala el script](#qué-instala-el-script)
- [Añadir una impresora](#añadir-una-impresora) (por GUI)
- [Descubrir y añadir por línea de comandos](#descubrir-y-añadir-por-línea-de-comandos)
- [Drivers](#drivers)
- [Diagnóstico](#diagnóstico)
- [Imprimir desde la terminal](#imprimir-desde-la-terminal)

## Cómo funciona

Tres piezas, cada una con un trabajo distinto:

| Pieza | Qué hace |
|-------|----------|
| **avahi-daemon** | Descubre la impresora en la red local por mDNS/DNS-SD. Es quien responde "hay una impresora en 192.168.x.x" sin que tengas que saber la IP. |
| **nss-mdns** | Engancha avahi al resolvedor de nombres del sistema. avahi hace el *descubrimiento*; esto es lo que hace que `IMPRESORA.local` además *resuelva* a una IP, para poder guardar la cola apuntando al hostname en vez de a una IP que el DHCP puede cambiar. |
| **cups** (`cups.socket`) | El servidor de impresión. Recibe el trabajo de la app, lo convierte con `cups-filters` y se lo manda a la impresora por IPP. |
| **system-config-printer** | La GUI para añadir y gestionar impresoras. Hyprland no trae panel propio. |

`cups.socket` está habilitado en vez de `cups.service`: systemd arranca `cupsd`
sólo cuando algo imprime o abre la GUI, en lugar de tenerlo corriendo siempre.

### El conflicto con systemd-resolved

`systemd-resolved` también implementa mDNS y viene con eso activado por defecto.
Con los dos demonios respondiendo en el puerto 5353 el descubrimiento sale
intermitente y ambos intentan publicar el mismo nombre `.local`. Por eso la
sección 7 del script escribe:

```ini
# /etc/systemd/resolved.conf.d/10-mdns-a-avahi.conf
[Resolve]
MulticastDNS=no
```

El mDNS queda en manos de avahi, que es el que CUPS consulta por D-Bus.

Pero apagarle el mDNS a resolved tiene una consecuencia: los nombres `.local`
dejan de resolver para todo el sistema. Por eso hace falta `nss-mdns`, que
engancha avahi al NSS. El script parchea la línea `hosts:` de
`/etc/nsswitch.conf` (dejando un respaldo con timestamp al lado):

```
hosts: mdns_minimal [NOTFOUND=return] mymachines resolve [!UNAVAIL=return] files myhostname dns
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ esto es lo que agrega
```

`mdns_minimal` sólo contesta nombres `.local`; para cualquier otro devuelve
UNAVAIL y la cadena sigue con `resolve`, `files` y `dns` como siempre.

### El firewall

`ufw` corre con política *deny incoming*. Las respuestas mDNS llegan como
multicast, no como respuesta a una conexión saliente rastreada, así que el
firewall las descarta y la impresora nunca se descubre. La regla que lo arregla
(también en la sección 7):

```bash
sudo ufw allow 5353/udp comment 'mDNS: descubrimiento de impresoras y servicios en la LAN'
```

## Qué instala el script

`archdesktopinstall.sh` lo cubre en dos lugares:

- **Sección 5** (paquetes): `cups`, `avahi`, `nss-mdns`, `system-config-printer`.
- **Sección 7** (servicios): el drop-in de resolved, el parche de
  `nsswitch.conf`, `avahi-daemon.service`, `cups.socket` y la regla de ufw.

No hace falta añadir el usuario a ningún grupo: el `cups-files.conf` de Arch trae
`SystemGroup sys root wheel` y el usuario ya está en `wheel` desde el instalador
de Arch. El grupo `lp` sólo hace falta para impresoras USB conectadas directo.

## Añadir una impresora

```bash
system-config-printer
```

"Añadir" → debería aparecer bajo **Impresoras de red**. La alternativa sin GUI es
la interfaz web de CUPS en <http://localhost:631> (pestaña *Administration* →
*Add Printer*; pide usuario y contraseña del sistema).

Para hacerlo por línea de comandos, primero hay que descubrirla.

## Descubrir y añadir por línea de comandos

### 1. El atajo: `driverless`

```bash
driverless list
```

Responde las dos preguntas de una: **si la impresora existe** y **si funciona sin
driver**. Si aparece en esta lista, es driverless — no le busques paquete de la
marca. Cada línea trae el URI ya armado:

```
"driverless:ipps://NOMBRE%20DE%20LA%20IMPRESORA._ipps._tcp.local/" en "MARCA" "MODELO, driverless, cups-filters 2.0.1" "MFG:...;MDL:...;CMD:PCLM,PWGRaster,AppleRaster,PWG,URF;"
```

Lo que importa de esa línea:

| Parte | Qué te dice |
|-------|-------------|
| `ipps://` vs `ipp://` | si soporta IPP sobre TLS. Usá `ipps` cuando esté. |
| `..._tcp.local/` | es un nombre de **servicio DNS-SD**, no un hostname. CUPS lo resuelve por avahi en cada trabajo, así que la cola sobrevive tanto a un cambio de IP como de hostname. Es el URI más robusto. |
| `CMD:...URF` / `PWGRaster` | los lenguajes que entiende. `URF` o `PWGRaster` = driverless de verdad. |

Si `driverless list` sale vacío pero la impresora está encendida, no es
driverless (o no la ve la red): seguí con el paso 2.

### 2. La vista completa: `avahi-browse`

```bash
avahi-browse -rt _ipp._tcp     # IPP en claro, puerto 631
avahi-browse -rt _ipps._tcp    # IPP sobre TLS
avahi-browse -at               # TODO lo que se anuncia en la red
```

El `-r` resuelve cada servicio (hostname, IP, puerto y registro TXT) y el `-t`
corta al terminar en vez de quedarse escuchando. Del bloque TXT vale la pena
leer:

| Campo | Para qué sirve |
|-------|----------------|
| `rp=` | la ruta del recurso, casi siempre `ipp/print`. Es lo que va al final del URI si armás uno por hostname. |
| `ty=` / `product=` | modelo real, que puede no coincidir con el nombre comercial. |
| `pdl=` | formatos que acepta. Con `image/pwg-raster` o `image/urf` es driverless. |
| `URF=` / `mopria-certified=` | confirman AirPrint / Mopria, o sea driverless. |
| `Color=`, `Duplex=`, `Scan=` | `T`/`F`. Evita buscar opciones que el equipo no tiene. |
| `adminurl=` | la web de administración de la impresora. |

Impresoras viejas que no hablan IPP se anuncian en otros servicios:

```bash
avahi-browse -rt _pdl-datastream._tcp   # puerto 9100 crudo  -> socket://IP:9100
avahi-browse -rt _printer._tcp          # LPD                -> lpd://IP/queue
```

Esas sí suelen necesitar driver (ver la tabla de [Drivers](#drivers)).

### 3. Añadirla

Con el URI del paso 1 (sacándole el prefijo `driverless:`). El `-m everywhere`
es IPP Everywhere: CUPS le pregunta a la impresora sus capacidades y arma el PPD
solo, sin driver.

```bash
sudo lpadmin -p NOMBRE_COLA -E -v URI_DEL_PASO_1 -m everywhere \
    -D "Descripción legible" -o printer-is-shared=false
sudo lpadmin -d NOMBRE_COLA        # dejarla como predeterminada
```

`NOMBRE_COLA` no admite espacios ni `/` ni `#`. Los espacios del URI van
codificados como `%20`.

Si preferís fijar el hostname en vez del nombre de servicio DNS-SD:
`-v ipp://HOSTNAME.local:631/ipp/print`, con el `HOSTNAME.local` y el `rp=` del
paso 2. Funciona gracias a `nss-mdns`, pero es menos robusto que el URI DNS-SD.
Lo que conviene evitar es la IP pelada: el DHCP puede reasignarla.

### 4. Verificar

```bash
lpstat -p -d                                  # ¿quedó la cola? ¿es la predeterminada?
lpoptions -p NOMBRE_COLA -l | head            # opciones que expuso (bandejas, calidad, dúplex)
lp -d NOMBRE_COLA /usr/share/cups/data/default-testpage.pdf
```

## Drivers

**No se instala ninguno a propósito.** Cualquier impresora de los últimos años
soporta IPP Everywhere / AirPrint, o sea que CUPS habla con ella sin driver.

Sólo si la tuya es vieja o imprime mal hace falta uno:

| Marca | Paquete | Dónde |
|-------|---------|-------|
| HP | `hplip` | repos oficiales |
| Epson | `epson-inkjet-printer-escpr` | repos oficiales |
| Brother | `brother-<modelo>` | AUR (`yay -S`), buscá tu modelo exacto |
| Canon / genéricas | `gutenprint` + `foomatic-db` | repos oficiales |

## Diagnóstico

Cuando la impresora no aparece, en este orden:

```bash
avahi-browse -rt _ipp._tcp          # ¿la ve la red? Si sale vacío, es avahi o el firewall
systemctl status avahi-daemon cups  # ¿están corriendo los dos?
sudo ufw status | grep 5353         # ¿está la regla de mDNS?
resolvectl mdns                     # debe decir 'no' en todos lados
lpstat -p -d                        # impresoras ya configuradas y cuál es la predeterminada
```

Si imprime en blanco o con basura, ahí sí el problema es el driver: probá el
paquete de la marca de la tabla de arriba.

Trabajos atascados en la cola:

```bash
lpstat -o          # ver la cola
cancel -a          # vaciarla
```

## Imprimir desde la terminal

```bash
lp archivo.pdf                      # a la impresora predeterminada
lp -d NOMBRE archivo.pdf            # a una específica (el nombre sale de 'lpstat -p')
lp -o sides=two-sided-long-edge archivo.pdf   # doble faz
lp -o media=A4 -o print-quality=5 archivo.pdf # tamaño y calidad
lpoptions -d NOMBRE                 # cambiar la impresora predeterminada
```
