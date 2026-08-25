#!/usr/bin/env bash
# Arregla el bluetooth muerto despues de la suspension en una maquina que YA tiene
# config_files clonado e instalado.
#
#   bash ~/config_files/scripts/fix-bluetooth-resume.sh --check   # solo diagnostica
#   bash ~/config_files/scripts/fix-bluetooth-resume.sh           # aplica el arreglo
#
# Diagnostico 2026-08-19 sobre un ThinkPad con btusb/btintel + Hyprland:
#
#   - Despues de un suspend/resume (s2idle) el journal muestra "Controller resume with
#     wake event 0x0" y todo PARECE sano: bluetooth.service active, 'Powered: yes', y
#     el radio recibe de verdad (ve decenas de dispositivos con RSSI bueno). Pero
#     ninguno de los emparejados se reconecta y un 'connect' a mano resuelve el GATT y
#     se cae al instante.
#
#   - La firma real del cuelgue es 'Discovering: yes' PEGADO en on sin que ningun
#     cliente haya pedido scan (no hay blueman ni applet corriendo, y 'scan off' no lo
#     baja). Un scan permanentemente activo se come la reconexion de los perifericos LE.
#     Se reproduce suspendiendo y despertando: no es rfkill ni la bateria.
#
#   - CORRECCION al diagnostico de la primera version de este script: 'systemctl
#     restart bluetooth.service' NO revive el controlador. Verificado a mano ese dia,
#     igual que un power off/on por mgmt ('bluetoothctl power off; power on'): las dos
#     cosas trabajan por encima del driver y las dos dejaron los 5 emparejados en
#     'Connected: no'. El estado pegado vive en el controlador/driver, asi que lo unico
#     que lo limpia es recargar el modulo, que vuelve a bajar el firmware.
#
# La solucion son dos piezas:
#
#   - bin_configs/bluetooth-reset, que hace el reset de verdad. A mano recarga el
#     modulo directo; con --resume prueba primero el reinicio barato del daemon y solo
#     recarga el modulo si la firma del cuelgue sigue ahi (asi no rebaja el firmware en
#     cada resume).
#   - bluetooth-resume.service, que lo corre al salir de la suspension
#     (WantedBy=suspend.target + After=suspend.target, el mismo idiom que
#     power-profile-sync.service).
#
# Es idempotente: reejecutarlo no rompe nada y sirve para verificar que sigue aplicado.
# Vive en scripts/ igual que fix-network-drops.sh.

set -e

solo_check=0
case "${1:-}" in
    --check|-n) solo_check=1 ;;
    "")         ;;
    *)          echo "Uso: $(basename "$0") [--check]"; exit 1 ;;
esac

# La ruta del repo se deduce de donde esta ESTE archivo, no de $HOME/config_files.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

unit_src="$repo/etc/systemd/system/bluetooth-resume.service"
unit_dst=/etc/systemd/system/bluetooth-resume.service
bin_src="$repo/bin_configs/bluetooth-reset"
bin_dst=/usr/local/bin/bluetooth-reset

ok()    { printf '   \033[32m✔\033[0m %s\n' "$*"; }
falta() { printf '   \033[33m→\033[0m %s\n' "$*"; }
mal()   { printf '   \033[31m✘\033[0m %s\n' "$*"; }
titulo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

estado() { systemctl is-enabled "$1" 2>/dev/null || true; }
activo() { systemctl is-active  "$1" 2>/dev/null || true; }

# --- 1. Comprobaciones previas ------------------------------------------------

titulo "1. Comprobaciones previas"

[ -f "$unit_src" ] || { mal "no existe $unit_src"; echo "     Actualiza el repo con: git -C $repo pull"; exit 1; }
ok "unit presente en el repo"

[ -x "$bin_src" ] || { mal "no existe (o no es ejecutable) $bin_src"; echo "     Actualiza el repo con: git -C $repo pull"; exit 1; }
ok "bluetooth-reset presente en el repo"

# GUARD: sin el servicio bluetooth no hay nada que revivir al despertar.
bt_activo="$(activo bluetooth.service)"
if [ "$bt_activo" = active ]; then
    ok "bluetooth.service activo"
else
    mal "bluetooth.service NO esta activo (esta '$bt_activo')"
    echo "     Arrancalo primero con: sudo systemctl enable --now bluetooth.service"
    exit 1
fi

# GUARD: sin controlador visible no tiene sentido el arreglo (podria ser un
# problema de hardware, no de suspend/resume).
if [ -e /sys/class/bluetooth/hci0 ]; then
    ok "controlador hci0 presente"
else
    mal "no hay /sys/class/bluetooth/hci0 -- esto no parece el bug de resume"
    echo "     Revisa:  journalctl -k -b | grep -i bluetooth"
    exit 1
fi

# --- 2. Estado actual ---------------------------------------------------------

titulo "2. Estado actual"

est="$(estado bluetooth-resume.service)"
if [ "$est" = enabled ]; then
    ok "bluetooth-resume.service: enabled"
else
    mal "bluetooth-resume.service: $est (deberia estar enabled)"
fi

if [ -f "$unit_dst" ] && cmp -s "$unit_src" "$unit_dst"; then
    ok "$unit_dst coincide con el repo"
else
    mal "$unit_dst no coincide con el repo (o no existe)"
fi

# El symlink lo repone tambien link-bins.sh, pero se comprueba aca porque la unit
# apunta a $bin_dst: si falta, el arreglo queda instalado y sin efecto al despertar.
if [ "$(readlink -f "$bin_dst" 2>/dev/null)" = "$bin_src" ]; then
    ok "$bin_dst -> $bin_src"
else
    mal "$bin_dst no apunta al repo (o no existe)"
fi

if [ "$solo_check" = 1 ]; then
    titulo "Modo --check: no se toco nada."
    echo "Para aplicar el arreglo, corre el script sin argumentos."
    echo "Para ver como esta el controlador ahora: bluetooth-reset --check"
    exit 0
fi

# --- 3. Instalar ---------------------------------------------------------------

titulo "3. Instalando bluetooth-reset y bluetooth-resume.service"

sudo ln -sfn "$bin_src" "$bin_dst"
ok "enlazado $bin_dst"

sudo install -Dm644 "$unit_src" "$unit_dst"
ok "instalado $unit_dst"
sudo systemctl daemon-reload
ok "daemon-reload"

sudo systemctl enable bluetooth-resume.service >/dev/null 2>&1
ok "bluetooth-resume.service enabled"

# --- 4. Verificacion ----------------------------------------------------------

titulo "4. Verificacion"

fallos=0

est_final="$(estado bluetooth-resume.service)"
if [ "$est_final" = enabled ]; then
    ok "bluetooth-resume.service: $est_final"
else
    mal "no quedo enabled ($est_final)"
    fallos=$((fallos+1))
fi

if [ -f "$unit_dst" ] && cmp -s "$unit_src" "$unit_dst"; then
    ok "$unit_dst coincide con el repo"
else
    mal "$unit_dst no coincide con el repo"
    fallos=$((fallos+1))
fi

if [ "$(readlink -f "$bin_dst" 2>/dev/null)" = "$bin_src" ]; then
    ok "$bin_dst -> $bin_src"
else
    mal "$bin_dst no apunta al repo"
    fallos=$((fallos+1))
fi

# La unit corre 'bluetooth-reset --resume' como root desde systemd, sin TTY: si el
# script pidiera sudo por password, al despertar se colgaria en vez de arreglar nada.
# Corriendo como root no entra en esa rama, pero se avisa si sudo NO esta.
if command -v sudo >/dev/null 2>&1; then
    ok "sudo disponible (lo usa bluetooth-reset a mano, no la unit)"
else
    mal "no hay sudo: 'bluetooth-reset' a mano habra que correrlo como root"
    fallos=$((fallos+1))
fi

if [ "$bt_activo" = active ]; then
    ok "bluetooth.service sigue activo"
else
    mal "bluetooth.service se cayo"
    fallos=$((fallos+1))
fi

titulo "$([ "$fallos" -eq 0 ] && echo "Listo, todo verificado." || echo "Terminado con $fallos problema(s) sin resolver.")"

cat <<EOF
Si el bluetooth esta muerto AHORA, sin esperar al proximo resume:

   bluetooth-reset            # reset completo (pide sudo)
   bluetooth-reset --check    # solo mirar como esta el controlador

Para probar el arreglo del resume:

   systemctl suspend
   # ... al despertar, los emparejados encendidos deberian reconectarse solos

Para revisar que hizo la unit al despertar:

   journalctl -u bluetooth-resume.service -b

Para revertirlo:

   sudo systemctl disable --now bluetooth-resume.service
   sudo rm /etc/systemd/system/bluetooth-resume.service /usr/local/bin/bluetooth-reset
   sudo systemctl daemon-reload
EOF
