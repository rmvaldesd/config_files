#!/usr/bin/env bash
# Arregla los cortes de red que tiran las conexiones largas (errores de API cada un par
# de horas) en una máquina que YA tiene config_files clonado e instalado.
#
#   bash ~/config_files/scripts/fix-network-drops.sh --check   # sólo diagnostica, no toca
#   bash ~/config_files/scripts/fix-network-drops.sh           # aplica los arreglos
#
# Arregla tres cosas independientes, diagnosticadas el 2026-08-12 sobre un ThinkPad con
# iwlwifi + Hyprland instalado con archinstall y después con archdesktopinstall.sh:
#
#   1. AHORRO DE ENERGÍA DEL WIFI. iwlwifi lo trae activado, la tarjeta se duerme entre
#      beacons y el kernel corta el enlace ("missed beacons exceeds threshold").
#      172 eventos en 6 días con la señal en 70/100.
#
#   2. systemd-networkd CORRIENDO EN PARALELO A NetworkManager sobre la misma interfaz.
#      Dos clientes DHCP, rutas duplicadas y una pelea por el sysctl de IPv6 visible en
#      el journal como "Foreign process 'NetworkManager' changed sysctl ...".
#
#   3. CERRAR LA TAPA SUSPENDE AUNQUE ESTÉ ENCHUFADO, porque logind viene con los
#      defaults. Explica los huecos de horas sin red.
#
# POR QUÉ LE PASA A TODOS LOS EQUIPOS INSTALADOS IGUAL, no es mala suerte de uno:
# archinstall deja /etc/systemd/network/20-{ethernet,wlan,wwan}.network y systemd trae
# un preset que habilita networkd (/usr/lib/systemd/system-preset/90-systemd.preset:30,
# 'enable systemd-networkd.service'), que le gana al 'disable *' de Arch por orden
# lexicográfico. Después archdesktopinstall.sh habilita NetworkManager (línea 269) y
# nadie apaga networkd. Resultado: dos gestores. Los tres puntos de arriba son
# reproducibles en cualquier equipo armado con esta misma receta.
#
# Es idempotente: reejecutarlo no rompe nada y sirve para verificar que sigue aplicado.
#
# Vive en scripts/ por la misma razón que enable-lock-profiles.sh: su trabajo es
# arreglar un equipo YA instalado, sin correr el instalador entero.

set -e

solo_check=0
case "${1:-}" in
    --check|-n) solo_check=1 ;;
    "")         ;;
    *)          echo "Uso: $(basename "$0") [--check]"; exit 1 ;;
esac

# La ruta del repo se deduce de dónde está ESTE archivo, no de $HOME/config_files. Así
# el script funciona igual si el repo está clonado en otro lado o si se lo invoca por un
# symlink. 'pwd -P' resuelve symlinks, que es el mismo cuidado que ya tiene
# enable-lock-profiles.sh al comparar rutas.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

conf_powersave="$repo/etc/NetworkManager/conf.d/wifi-powersave.conf"
conf_tapa="$repo/etc/systemd/logind.conf.d/10-lid.conf"

ok()    { printf '   \033[32m✔\033[0m %s\n' "$*"; }
falta() { printf '   \033[33m→\033[0m %s\n' "$*"; }
mal()   { printf '   \033[31m✘\033[0m %s\n' "$*"; }
titulo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

# systemctl is-enabled / is-active devuelven != 0 cuando la respuesta es "disabled" o
# "inactive", que acá son respuestas válidas, no errores. Con 'set -e' arriba hay que
# envolverlas o el script se muere en la primera consulta.
estado()  { systemctl is-enabled "$1" 2>/dev/null || true; }
activo()  { systemctl is-active  "$1" 2>/dev/null || true; }
existe()  { systemctl cat "$1" >/dev/null 2>&1; }

# --- 1. Comprobaciones previas ------------------------------------------------
# Todas ANTES de tocar nada: un fallo a mitad de camino podría dejar el equipo sin
# ningún gestor de red, que es bastante peor que el estado inicial.

titulo "1. Comprobaciones previas"

[ -f "$conf_powersave" ] || { mal "no existe $conf_powersave"; echo "     Actualiza el repo con: git -C $repo pull"; exit 1; }
[ -f "$conf_tapa" ]      || { mal "no existe $conf_tapa";      echo "     Actualiza el repo con: git -C $repo pull"; exit 1; }
ok "archivos de configuracion presentes en el repo"

# La interfaz wifi NO se escribe a mano: cambia de nombre entre equipos según el slot
# PCI (wlp0s20f3 acá, wlan0 o wlp3s0 en otro). Se pregunta a NM y si no contesta se cae
# a sysfs, que funciona incluso con NM detenido.
iface="$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}' || true)"
if [ -z "$iface" ]; then
    for d in /sys/class/net/*/wireless; do
        [ -e "$d" ] && iface="$(basename "$(dirname "$d")")" && break
    done
fi
if [ -n "$iface" ]; then
    ok "interfaz wifi detectada: $iface"
else
    falta "no hay interfaz wifi: el punto del powersave se va a saltear"
fi

# GUARD CRÍTICO. Apagar networkd sólo es seguro si NetworkManager es el que realmente
# está manejando la red. Si en este equipo la red la lleva networkd (o iwd, o dhcpcd),
# apagarlo lo dejaría OFFLINE y encima por SSH sería irrecuperable.
nm_activo="$(activo NetworkManager)"
if [ "$nm_activo" = "active" ]; then
    ok "NetworkManager activo: es seguro apagar networkd"
    tocar_networkd=1
else
    mal "NetworkManager NO esta activo (esta '$nm_activo')"
    echo "     No se toca networkd: apagarlo dejaria el equipo SIN RED."
    echo "     Si este equipo usa networkd a proposito, el punto 2 no le aplica."
    echo "     Si deberia usar NM:  sudo systemctl enable --now NetworkManager"
    tocar_networkd=0
fi

# La tapa sólo tiene sentido donde hay tapa. En un equipo de escritorio la opción es
# inofensiva pero no hace nada, así que mejor no ensuciar /etc.
if [ -d /proc/acpi/button/lid ] && [ -n "$(ls -A /proc/acpi/button/lid 2>/dev/null)" ]; then
    hay_tapa=1
    ok "el equipo tiene tapa"
elif compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    hay_tapa=1
    ok "el equipo tiene bateria (se asume portatil)"
else
    hay_tapa=0
    falta "sin tapa ni bateria: el punto de la tapa se va a saltear"
fi

# --- 2. Diagnóstico -----------------------------------------------------------
# Se imprime siempre, aunque después se apliquen los cambios, para poder comparar el
# antes y el después en la misma salida.

titulo "2. Estado actual"

if [ -n "$iface" ]; then
    if command -v iw >/dev/null 2>&1; then
        ps_actual="$(iw dev "$iface" get power_save 2>&1 | grep -oE '(on|off)$' || echo '?')"
        [ "$ps_actual" = off ] && ok "powersave del wifi: off" || mal "powersave del wifi: $ps_actual"
    else
        falta "powersave: no se puede medir todavia, falta el paquete 'iw'"
    fi
fi

nd_activo="$(activo systemd-networkd)"
if [ "$nd_activo" = active ]; then
    mal "systemd-networkd ACTIVO (peleando con NetworkManager)"
else
    ok "systemd-networkd: $nd_activo"
fi

# Rutas duplicadas: el síntoma más directo de los dos gestores. Se cuenta cuántas rutas
# de link-scope hay para la misma red en la misma interfaz; con un solo gestor hay una.
if [ -n "$iface" ]; then
    red="$(ip -o -f inet route show dev "$iface" scope link 2>/dev/null | awk '{print $1}' | sort | uniq -d | head -1 || true)"
    if [ -n "$red" ]; then
        mal "rutas DUPLICADAS para $red en $iface (dos gestores configurando)"
    else
        ok "sin rutas duplicadas"
    fi
fi

if [ "$hay_tapa" = 1 ]; then
    if systemd-analyze cat-config systemd/logind.conf 2>/dev/null | grep -qiE "^[[:space:]]*HandleLidSwitchExternalPower[[:space:]]*=[[:space:]]*ignore"; then
        ok "tapa con cargador: ignore (no suspende)"
    else
        mal "tapa con cargador: suspend (el default) -- suspende aunque este enchufado"
    fi
fi

if [ "$solo_check" = 1 ]; then
    titulo "Modo --check: no se toco nada."
    echo "Para aplicar los arreglos, corre el script sin argumentos."
    exit 0
fi

# --- 3. Instalar 'iw' ---------------------------------------------------------
# Primero de todo, mientras la red está estable: más abajo se reactiva la conexión y ahí
# pacman no podría bajar nada.
#
# A propósito SIN -Sy. Un 'pacman -Sy <paquete>' suelto es exactamente la receta de la
# actualización parcial que rompe Arch. Si la base de datos de sync ya tiene el paquete
# (el caso normal), -S solo alcanza; si no, el script avisa y sigue, porque 'iw' es para
# VERIFICAR, no para arreglar: el arreglo del powersave lo hace NetworkManager.

titulo "3. Paquete 'iw' (para poder medir el powersave)"
if command -v iw >/dev/null 2>&1; then
    ok "ya estaba instalado"
elif sudo pacman -S --needed --noconfirm iw >/dev/null 2>&1; then
    ok "instalado"
else
    falta "no se pudo instalar. Despues, aparte:  sudo pacman -Syu iw"
    falta "no afecta al arreglo, solo a la verificacion del final"
fi

# --- 4. Desactivar el ahorro de energía del wifi -------------------------------

titulo "4. Ahorro de energia del wifi"
sudo install -Dm644 "$conf_powersave" /etc/NetworkManager/conf.d/wifi-powersave.conf
ok "instalado /etc/NetworkManager/conf.d/wifi-powersave.conf"
sudo nmcli general reload conf
ok "config de NetworkManager recargada"
falta "se hace efectivo al reactivar la conexion (paso 7)"

# --- 5. Sacar systemd-networkd de encima de la interfaz ------------------------
# systemd-resolved NO se toca: NM lo usa bien, es la combinación normal en Arch y
# archdesktopinstall.sh ya le deja config propia en /etc/systemd/resolved.conf.d.

titulo "5. systemd-networkd"
if [ "$tocar_networkd" = 0 ]; then
    falta "salteado por el guard del paso 1"
elif ! existe systemd-networkd.service; then
    ok "networkd no existe en este equipo, nada que hacer"
else
    # ACÁ ESTÁ LA PARTE QUE HAY QUE ENTENDER, porque el intento obvio NO funciona.
    #
    # 'systemctl disable --now systemd-networkd systemd-networkd.socket' parece
    # suficiente y no lo es: systemd-networkd.service se activa por socket, y tiene
    # VARIOS sockets que lo disparan, no uno. En systemd 261 son cuatro:
    #
    #   systemd-networkd.socket
    #   systemd-networkd-varlink.socket
    #   systemd-networkd-varlink-metrics.socket
    #   systemd-networkd-resolve-hook.socket
    #
    # Verificado a la mala: desactivando sólo el primero, networkd volvió a estar
    # 'active' con PID nuevo a los segundos, releyó los .network de archinstall y se
    # puso otra vez a pelear por la interfaz -- quedando 'disabled' y 'active' a la vez,
    # que es justo el estado que hace pensar que el arreglo funcionó.
    #
    # Por eso acá se usa 'mask' y no 'disable': mask apunta la unidad a /dev/null, así
    # que fallan TODAS las vías de activación (socket, D-Bus, dependencia de otra
    # unidad) y no sólo el arranque. Además sobrevive al preset de systemd, que si no
    # volvería a habilitar networkd en cualquier 'systemctl preset-all' o reinstalación
    # del paquete systemd.
    #
    # La lista de disparadores se ENUMERA EN TIEMPO DE EJECUCIÓN en vez de escribirla a
    # mano, porque los nombres de los sockets varlink cambian entre versiones de systemd
    # y un equipo con otra versión tendría otro juego. Preguntarle a systemd es lo único
    # que no se desactualiza.
    unidades=(systemd-networkd.service systemd-networkd-wait-online.service)
    disparadores="$(systemctl show systemd-networkd.service -p TriggeredBy --value 2>/dev/null || true)"
    for s in $disparadores; do unidades+=("$s"); done

    for u in "${unidades[@]}"; do
        existe "$u" || continue
        sudo systemctl mask --now "$u" >/dev/null 2>&1 || sudo systemctl mask "$u" >/dev/null 2>&1 || true
        ok "mask $u"
    done

    # NM-wait-online en su lugar, para que network-online.target siga significando algo
    # en el arranque ahora que el de networkd está enmascarado.
    if existe NetworkManager-wait-online.service; then
        sudo systemctl enable NetworkManager-wait-online >/dev/null 2>&1 || true
        ok "NetworkManager-wait-online enabled"
    fi

    # Cinturón y tiradores: neutralizar los .network que dejó archinstall. Con networkd
    # enmascarado ya no los lee nadie, pero si alguien lo desenmascara alguna vez para
    # depurar, el conflicto volvería en silencio. Renombrar a .disabled basta porque
    # networkd sólo lee *.network.
    #
    # Se toca SÓLO el trío exacto de archinstall, y sólo si ningún paquete lo instaló y
    # el contenido es el suyo. Sin esos tres filtros el script podría pisar un .network
    # escrito a mano a propósito en otro equipo.
    for f in /etc/systemd/network/20-ethernet.network \
             /etc/systemd/network/20-wlan.network \
             /etc/systemd/network/20-wwan.network; do
        [ -f "$f" ] || continue
        pacman -Qo "$f" >/dev/null 2>&1 && continue   # lo instaló un paquete: no es de archinstall
        grep -q "does not set per-interface-type default route metrics" "$f" 2>/dev/null || continue
        sudo mv "$f" "$f.disabled"
        ok "neutralizado $(basename "$f") -> $(basename "$f").disabled"
    done
fi

# --- 6. Que la tapa no suspenda con cargador ----------------------------------

titulo "6. Tapa"
if [ "$hay_tapa" = 0 ]; then
    falta "salteado: el equipo no es portatil"
else
    sudo install -Dm644 "$conf_tapa" /etc/systemd/logind.conf.d/10-lid.conf
    ok "instalado /etc/systemd/logind.conf.d/10-lid.conf"
    # reload y NO restart: verificado que logind tiene CanReload=yes en systemd 261, así
    # que releer la config no corta la sesión gráfica. Un restart la mataría.
    sudo systemctl reload systemd-logind
    ok "logind recargado (sin cortar la sesion grafica)"
fi

# --- 7. Reactivar la conexión -------------------------------------------------
# Es lo que hace efectivo el powersave: NM lo aplica al ACTIVAR la conexión, no al
# recargar la config. Y de paso deja que NM reescriba las rutas que networkd duplicaba.

if [ -n "$iface" ]; then
    titulo "7. Reactivando la conexion (se corta la red unos segundos)"
    con="$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: -v i="$iface" '$2==i{print $1; exit}' || true)"
    if [ -n "$con" ]; then
        nmcli connection down "$con" >/dev/null 2>&1 || true
        nmcli connection up   "$con" >/dev/null 2>&1 || true
        ok "reactivada '$con'"
    else
        nmcli device connect "$iface" >/dev/null 2>&1 || true
        ok "dispositivo $iface levantado"
    fi
    for _ in $(seq 30); do
        ip route get 1.1.1.1 >/dev/null 2>&1 && break
        sleep 1
    done
fi

# --- 8. Verificación ----------------------------------------------------------
# Se verifica el EFECTO, no que los comandos hayan devuelto 0. El fallo del intento
# anterior (networkd revivido por otro socket) devolvía 0 en todos los pasos.

titulo "8. Verificacion"

fallos=0

if [ -n "$iface" ]; then
    if command -v iw >/dev/null 2>&1; then
        ps_final="$(iw dev "$iface" get power_save 2>&1 | grep -oE '(on|off)$' || echo '?')"
        if [ "$ps_final" = off ]; then
            ok "powersave: off"
        else
            mal "powersave: $ps_final  <-- deberia decir off"
            echo "     Plan B, por driver:  echo 'options iwlwifi power_save=0' | sudo tee /etc/modprobe.d/iwlwifi.conf"
            echo "     (requiere reiniciar para que tome efecto)"
            fallos=$((fallos+1))
        fi
    else
        falta "powersave: sin 'iw' no se puede medir"
    fi
fi

if [ "$tocar_networkd" = 1 ] && existe systemd-networkd.service; then
    # La prueba de fuego: provocar la activación por socket y confirmar que NO revive.
    # Sin este paso, el bug del intento anterior habría pasado desapercibido.
    networkctl status >/dev/null 2>&1 || true
    sleep 3
    nd_final="$(activo systemd-networkd)"
    if [ "$nd_final" = active ]; then
        mal "systemd-networkd SIGUE ACTIVO despues de provocarlo"
        fallos=$((fallos+1))
    else
        ok "systemd-networkd: $nd_final (no revive ni provocandolo)"
    fi
fi

if [ -n "$iface" ]; then
    red="$(ip -o -f inet route show dev "$iface" scope link 2>/dev/null | awk '{print $1}' | sort | uniq -d | head -1 || true)"
    [ -z "$red" ] && ok "sin rutas duplicadas" || { mal "rutas duplicadas para $red"; fallos=$((fallos+1)); }
fi

if [ "$hay_tapa" = 1 ]; then
    if systemd-analyze cat-config systemd/logind.conf 2>/dev/null | grep -qiE "^[[:space:]]*HandleLidSwitchExternalPower[[:space:]]*=[[:space:]]*ignore"; then
        ok "tapa con cargador: ignore"
    else
        mal "tapa con cargador: sigue en suspend"
        fallos=$((fallos+1))
    fi
fi

if ping -c2 -W3 1.1.1.1 >/dev/null 2>&1; then
    ok "ping a 1.1.1.1"
else
    mal "sin conectividad IP  <-- NO cierres esta terminal hasta resolverlo"
    echo "     sudo systemctl restart NetworkManager"
    fallos=$((fallos+1))
fi

if getent hosts api.anthropic.com >/dev/null 2>&1; then
    ok "DNS api.anthropic.com"
else
    mal "falla el DNS"
    fallos=$((fallos+1))
fi

titulo "$([ "$fallos" -eq 0 ] && echo "Listo, todo verificado." || echo "Terminado con $fallos problema(s) sin resolver.")"

cat <<EOF
Para revisar mas adelante si los cortes se terminaron:

   # cortes de wifi por dia (deberia bajar a casi cero)
   journalctl --since "3 days ago" | grep -c "Connection to AP .* lost"

   # perdidas de beacons por dia
   journalctl --since "3 days ago" | grep -c "missed beacons exceeds threshold"

Para revertirlo todo:

   sudo systemctl unmask systemd-networkd.service systemd-networkd.socket
   sudo rm /etc/NetworkManager/conf.d/wifi-powersave.conf
   sudo rm /etc/systemd/logind.conf.d/10-lid.conf
   sudo systemctl reload systemd-logind
   for f in /etc/systemd/network/*.network.disabled; do sudo mv "\$f" "\${f%.disabled}"; done

Si los cortes siguen despues de esto, ya no es el equipo: es la red. Con varios nodos
en el mismo SSID el cliente salta entre ellos y cada salto reinicia DHCP. Para verlo:

   journalctl --since "2 days ago" | grep -oE "Associated with [0-9a-f:]{17}" | sort | uniq -c
EOF
