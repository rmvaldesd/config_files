#!/usr/bin/env python3
#
# Módulo custom/submap de waybar.
#
# En la barra: un icono que dice QUÉ modo modal está activo -- una regla para resize,
# un monitor para monitor -- y nada cuando no hay ninguno. En el tooltip, la palabra y
# las teclas de ese modo, que es lo que uno olvida justo cuando entra.
#
# Reemplaza al módulo estándar 'hyprland/submap', que funcionaba pero sólo sabe mostrar
# UN texto fijo para todos los submapas: no soporta 'format-icons' (probado -- con
# "format": "{icon}" el texto sale vacío y waybar esconde el módulo entero) y su
# 'format' admite como único valor variable '{}', el nombre del submapa. Con él, lo más
# lejos que se llegaba era el mismo icono para los dos modos y el color como distinción.
#
# NO hace polling ni necesita que nadie le avise: se cuelga del socket de EVENTOS de
# Hyprland (.socket2.sock), que emite 'submap>>nombre' al entrar y 'submap>>' (vacío) al
# salir. Esto importa más de lo que parece. La alternativa era que hyprland.lua mandara
# una señal en cada entrada y cada salida de submapa, y las salidas son varias -- Return
# y Escape de 'resize', Return y Escape de 'monitor', que además salen por un exec_cmd
# con sort-workspaces adentro. Olvidarse de una sola deja el icono clavado mostrando un
# modo del que ya saliste. Escuchando el evento no hay nada que recordar, y hyprland.lua
# no se toca.
#
# ES PYTHON Y NO BASH, a diferencia de swap.sh y disk.sh, y no es capricho: bash no sabe
# hablar sockets unix, así que necesita a la fuerza un proceso externo que lea el socket
# (socat y nc no están instalados; python sí, está explícito en la lista del instalador).
# Y esa versión en bash tenía un bug real: al morir el bash raíz, el lector del socket y
# el subshell del pipe quedaban HUÉRFANOS sosteniendo el pipe abierto, así que waybar
# nunca veía EOF y no volvía a levantar el módulo -- quedaba mudo hasta el próximo login.
# Verificado matando el proceso a mano. Un solo proceso no tiene ese problema: cuando
# waybar lo mata, no queda nada atrás.
#
# Waybar lo corre en modo continuo: sin 'interval', leyendo una línea JSON por evento. Si
# Hyprland se reinicia, el socket muere, este script termina y el 'restart-interval' del
# config lo vuelve a levantar (verificado).

import json
import os
import socket
import subprocess
import sys

# Icono por modo. El default cubre cualquier submapa que se agregue a hyprland.lua sin
# pasar por acá: un teclado genérico, que al menos avisa que hay un modo activo. Los
# glifos son de "Symbols Nerd Font", que viene versionada en config_files/fonts, y van
# por codepoint y no como carácter suelto para que se vean en cualquier editor.
ICONOS = {
    "resize": "\U000F0A68",   # nf-md-resize
    "monitor": "\U000F0379",  # nf-md-monitor
}
ICONO_DEFAULT = "\U000F030C"  # nf-md-keyboard

# Las teclas de cada modo, que son las que uno no se acuerda al entrar. Salen de las
# definiciones de submapa de hyprland.lua; si allá cambian los binds, acá también.
AYUDAS = {
    "resize": "resize mode: H/L width, I/J height. Enter or Esc to exit",
    "monitor": "monitor mode: H/L/I/K or arrows move the workspace. Enter or Esc to exit",
}


def emitir(nombre):
    """Una línea JSON por evento.

    Un texto vacío hace que waybar esconda el módulo entero, que es justo lo que se
    quiere fuera de un submapa: ni icono, ni pastilla, ni hueco. Es el mismo patrón que
    custom/swap y custom/rclone usan en un equipo que no los tiene.

    El 'class' es lo que style.css usa para pintar la pastilla de cada modo, y json.dumps
    se encarga del escapado -- incluido el caso de un submapa con comillas en el nombre,
    que a mano habría que acordarse de contemplar.

    'ensure_ascii=False' NO es opcional y cuesta caro olvidarlo: los glifos Nerd Font
    viven arriba del plano básico (U+F0A68), y json.dumps por defecto los escapa como par
    suplente ("\\udb82\\ude68"). Waybar no los rearma, así que el módulo sale vacío -- no
    da error, simplemente no se ve, que es lo peor para darse cuenta. Con False el JSON
    lleva el carácter en UTF-8 crudo, igual que el printf de swap.sh.
    """
    nombre = (nombre or "").strip()
    if not nombre or nombre == "default":
        salida = {"text": "", "class": "", "tooltip": ""}
    else:
        salida = {
            "text": ICONOS.get(nombre, ICONO_DEFAULT),
            "class": nombre,
            "tooltip": AYUDAS.get(nombre, "%s mode. Enter or Esc to exit" % nombre),
        }
    print(json.dumps(salida, ensure_ascii=False), flush=True)


def submap_actual():
    """Estado inicial: si waybar arranca (o se recarga con SIGUSR2) mientras hay un
    submapa activo, sin esto el módulo quedaría vacío hasta el próximo evento."""
    try:
        r = subprocess.run(["hyprctl", "submap"], capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def main():
    emitir(submap_actual())

    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    firma = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not runtime or not firma:
        return 0
    ruta = os.path.join(runtime, "hypr", firma, ".socket2.sock")

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(ruta)
    except OSError:
        # Sin socket no hay nada que escuchar. Se sale en silencio y con estado 0: el
        # módulo ya emitió el estado inicial, y el 'restart-interval' reintentará.
        return 0

    buf = b""
    with s:
        while True:
            datos = s.recv(4096)
            if not datos:
                break  # Hyprland se fue: que waybar vea EOF y relance el script.
            buf += datos
            *lineas, buf = buf.split(b"\n")
            for linea in lineas:
                linea = linea.decode("utf-8", "replace")
                if linea.startswith("submap>>"):
                    emitir(linea[len("submap>>"):])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (BrokenPipeError, KeyboardInterrupt):
        # Waybar cerró el pipe o mató el proceso: es la salida normal, no un error.
        sys.exit(0)
