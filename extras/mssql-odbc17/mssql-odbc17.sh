#!/usr/bin/env bash
# Instala o desinstala el driver ODBC 17 de Microsoft para SQL Server.
# Equivalente en Arch a lo que en Fedora se instalaba como msodbcsql17 + unixODBC-devel.
#
# Vive en extras/ porque NO es parte del entorno base que arma archdesktopinstall.sh:
# se corre a mano en las máquinas donde haga falta conectarse a SQL Server.
#
#   ./mssql-odbc17/mssql-odbc17.sh install     # instala el driver, sus deps y lo deja registrado
#   ./mssql-odbc17/mssql-odbc17.sh uninstall   # da de baja el stack
#   ./mssql-odbc17/mssql-odbc17.sh status      # si tu aplicación va a poder cargar el driver o no
#   ./mssql-odbc17/mssql-odbc17.sh             # menú interactivo con esas tres opciones
#
# Los comentarios van en español como el resto del repo; los mensajes en inglés.

set -euo pipefail

morir()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
aviso()  { printf '\033[33m->\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m->\033[0m %s\n' "$*"; }

# yay/makepkg se niegan a compilar como root, y correr esto con sudo pediría la
# clave dos veces por nada. Mismo criterio que el resto de extras/.
[ "$EUID" -eq 0 ] && morir "do not run this as root/sudo; it will ask for sudo when needed."

# Arch no separa runtime/-devel: un solo paquete trae libodbc, odbcinst, isql y los
# headers para compilar contra ODBC (lo que en Fedora era unixODBC + unixODBC-devel).
PAQUETES_REPO=(
    unixodbc   # Driver manager ODBC (libodbc.so, odbcinst, isql) + headers. El driver se registra contra esto y tu app lo carga a través suyo.
)

# No hay paquetes oficiales de Microsoft para Arch: estos son de AUR y repackean el
# .rpm oficial de Microsoft (la misma fuente que usa Fedora/RHEL).
PAQUETES_AUR=(
    msodbcsql17   # El driver. OJO: el paquete AUR está HUÉRFANO y clavado en 17.10.2.1 (nov 2022); si algún día el .rpm de packages.microsoft.com desaparece, este build deja de funcionar.
    openssl-1.1   # NO es opcional, ver bloque de abajo. Instala libssl.so.1.1 y libcrypto.so.1.1 en /usr/lib.
)

PAQUETES=("${PAQUETES_REPO[@]}" "${PAQUETES_AUR[@]}")

# ¿Por qué openssl-1.1 es obligatorio y no un "por si acaso"?
# El driver no linkea OpenSSL: lo abre con dlopen() en tiempo de conexión, armando el
# nombre a mano. Los sufijos que sabe probar están embebidos en el .so y son SÓLO de la
# serie 1.x (.so.1.1, .so.1.0.2, .so.1.0.1, .so.1.0.0, .so.10): no conoce .so.3. Arch
# hoy sólo trae OpenSSL 3, así que sin este paquete el driver carga bien pero toda
# conexión TLS falla. Verificado con readelf/strings sobre libmsodbcsql-17.10.so.2.1.
OPENSSL_SONAMES=(.so.1.1 .so.1.0.2 .so.1.0.1 .so.1.0.0 .so.10)

# mssql-tools (sqlcmd/bcp) NO está acá a propósito: el paquete de AUR con ese nombre
# empaqueta en realidad la build 18, y sus binarios traen clavado el driver 18
# ('DRIVER={ODBC Driver 18 for SQL Server}' aparece literal dentro de bcp). Con sólo el
# driver 17 instalado fallan al conectar, así que instalarlos obligaría a arrastrar
# también msodbcsql (18). Para probar conexiones alcanza con isql, que trae unixodbc.

DRIVER_NOMBRE="ODBC Driver 17 for SQL Server"
DRIVER_ODBCINST_INI="/opt/microsoft/msodbcsql17/etc/odbcinst.ini"

# ==========================================
# HELPERS DE COMPROBACIÓN
# ==========================================
# La salida de `ldconfig -p` se guarda una sola vez. No es (sólo) por ahorrarse forks:
# con pipefail, `ldconfig -p | grep -q ...` da FALSO NEGATIVO. grep -q corta al primer
# match y cierra el pipe, ldconfig muere por SIGPIPE (141) y pipefail da por fallada la
# pipeline entera aunque el match haya existido. Contra un here-string no hay pipeline.
CACHE_LINKER=""
cargar_cache_linker() {
    [ -n "$CACHE_LINKER" ] && return 0
    CACHE_LINKER=$(ldconfig -p 2>/dev/null) || true
}

# Busca un soname en la caché del linker, que es donde dlopen() lo va a buscar.
lib_en_cache() {
    cargar_cache_linker
    grep -qE "^[[:space:]]*$1 " <<< "$CACHE_LINKER"
}

# Devuelve 0 si hay un par libssl/libcrypto de los que el driver sabe abrir.
openssl_compatible() {
    local suf
    for suf in "${OPENSSL_SONAMES[@]}"; do
        if lib_en_cache "libssl$suf" && lib_en_cache "libcrypto$suf"; then
            printf 'libssl%s + libcrypto%s' "$suf" "$suf"
            return 0
        fi
    done
    return 1
}

# ==========================================
# COMPROBAR DRIVER (lo que de verdad ve una app al conectar)
# ==========================================
# Tres cosas distintas pueden estar mal y dan errores muy parecidos:
#   1. el driver no está registrado -> la app ni lo encuentra
#   2. está registrado pero el .so no carga -> falta una lib de las que linkea
#   3. carga pero no puede hacer TLS -> falta OpenSSL 1.x, que abre por dlopen
# El punto 3 es invisible para ldd (no está en NEEDED), así que se chequea aparte.
comprobar_driver() {
    local fallo=0

    if ! command -v odbcinst > /dev/null; then
        aviso "unixodbc is not installed; nothing can load the driver yet."
        return 1
    fi

    # --- 1. registro ---
    # Mismo motivo que en lib_en_cache: nada de `... | grep -q` con pipefail activo.
    local registrados
    registrados=$(odbcinst -q -d 2>/dev/null) || true
    if ! grep -qF "$DRIVER_NOMBRE" <<< "$registrados"; then
        aviso "NOT registered: no '$DRIVER_NOMBRE' entry in odbcinst.ini."
        aviso "  Your app would fail with 'Data source name not found / no default driver'."
        aviso "  Fix: sudo odbcinst -i -d -f $DRIVER_ODBCINST_INI"
        return 1
    fi

    local ruta
    ruta=$(odbcinst -q -d -n "$DRIVER_NOMBRE" 2>/dev/null | sed -n 's/^[[:space:]]*Driver[[:space:]]*=[[:space:]]*//p' | head -1) || true
    if [ -z "$ruta" ]; then
        aviso "Registered, but odbcinst.ini has no readable Driver= line for it."
        return 1
    fi
    if [ ! -e "$ruta" ]; then
        aviso "Registered, but its Driver= points to $ruta, which does NOT exist."
        return 1
    fi
    ok "Registered: $DRIVER_NOMBRE"
    printf '     -> %s\n' "$ruta"

    # --- 2. libs que el .so linkea (esto sí lo ve ldd) ---
    local faltantes
    faltantes=$(ldd "$ruta" 2>/dev/null | awk '/not found/{print $1}') || true
    if [ -n "$faltantes" ]; then
        aviso "The driver itself won't load; missing linked libraries:"
        printf '%s\n' "$faltantes" | sed 's/^/       /'
        fallo=1
    fi

    # --- 3. OpenSSL, que NO aparece en ldd porque va por dlopen ---
    local par
    if par=$(openssl_compatible); then
        ok "OpenSSL for TLS: $par"
    else
        aviso "No usable OpenSSL: the driver only dlopen()s the 1.x series"
        aviso "  (${OPENSSL_SONAMES[*]}), and this system has:"
        cargar_cache_linker
        grep -E '^[[:space:]]*lib(ssl|crypto)\.so' <<< "$CACHE_LINKER" | sed 's/^[[:space:]]*/       /' || printf '       (none)\n'
        aviso "  Every TLS connection will fail. Fix: yay -S openssl-1.1"
        fallo=1
    fi

    if [ "$fallo" -eq 0 ]; then
        ok "Your application should be able to load and use this driver."
        return 0
    fi
    aviso "Your application will NOT be able to use this driver until the above is fixed."
    return 1
}

# ==========================================
# ESTADO
# ==========================================
estado() {
    printf '\n\033[1m=== MS SQL Server ODBC driver status ===\033[0m\n\n'

    printf '%-14s %s\n' "PACKAGE" "INSTALLED"
    local p v
    for p in "${PAQUETES[@]}"; do
        v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}') || true
        printf '%-14s %s\n' "$p" "${v:--}"
    done

    printf '\n'
    comprobar_driver || true
    printf '\n'
}

# ==========================================
# INSTALAR
# ==========================================
instalar() {
    command -v yay > /dev/null || \
        morir "yay (AUR helper) not found; the driver comes from the AUR. Install yay first (archdesktopinstall.sh does it) and re-run."

    sudo -v

    aviso "Installing unixODBC..."
    sudo pacman -S --needed --noconfirm "${PAQUETES_REPO[@]}"

    # Al compilar el .rpm de Microsoft estás aceptando su EULA (queda en
    # /usr/share/licenses/msodbcsql17/LICENSE.txt); es el equivalente al ACCEPT_EULA=Y
    # de Fedora, sólo que acá no hay ningún prompt que lo pida.
    # Van en una sola transacción: no dependen entre sí, y openssl-1.1 hace falta
    # igual antes de la primera conexión.
    aviso "Building and installing the driver + OpenSSL 1.1 from the AUR (this compiles; it takes a while)..."
    yay -S --needed --noconfirm "${PAQUETES_AUR[@]}"

    printf '\n'
    # El registro lo hace el hook post_install del propio paquete AUR; acá sólo se
    # verifica que haya quedado bien, junto con todo lo demás.
    if comprobar_driver; then
        printf '\n'
        ok "Done."
    else
        printf '\n'
        aviso "Installed, but the checks above did not pass. Fix them before using the driver."
    fi

    printf '\n'
    aviso "Use it from your app by the exact driver name:"
    aviso "  Driver={$DRIVER_NOMBRE}          # connection string / pyodbc"
    aviso "List registered drivers:  odbcinst -q -d"
    aviso "To test an actual connection, define a DSN in ~/.odbc.ini and run: isql -v <DSN>"
}

# ==========================================
# DESINSTALAR
# ==========================================
desinstalar() {
    local confirmar
    read -rp "Remove the MS SQL ODBC driver stack? [y/N]: " confirmar
    [[ "$confirmar" =~ ^[yYsS]$ ]] || { aviso "Cancelled."; exit 0; }

    sudo -v

    # openssl-1.1 NO se toca: es una librería compartida y cualquier otro paquete de
    # AUR puede estar usándola; si se la sumara a un -Rns y algo dependiera de ella,
    # pacman abortaría la transacción entera. Se avisa al final y se borra a mano.
    local instalados=() p
    for p in "${PAQUETES_REPO[@]}" msodbcsql17; do
        pacman -Qq "$p" &> /dev/null && instalados+=("$p")
    done

    if [ "${#instalados[@]}" -eq 0 ]; then
        aviso "No packages from the stack are installed; nothing to remove."
    else
        aviso "Removing: ${instalados[*]}"
        # Un solo -Rns: pacman ordena la remoción por dependencias (msodbcsql17 antes
        # que unixodbc), así que el hook pre_remove del driver todavía encuentra el
        # binario odbcinst para desregistrarse. Invertido, dejaría la entrada colgada.
        sudo pacman -Rns --noconfirm "${instalados[@]}"
    fi

    printf '\n'
    ok "Uninstalled."
    if pacman -Qq openssl-1.1 &> /dev/null; then
        aviso "openssl-1.1 was left installed (other AUR packages may link against it)."
        aviso "  Remove it by hand if nothing else needs it: yay -Rns openssl-1.1"
    fi
}

# ==========================================
# ENTRADA
# ==========================================
case "${1:-}" in
    install)   instalar ;;
    uninstall) desinstalar ;;
    status)    estado ;;
    "")
        printf '\n\033[1m=== MS SQL Server ODBC driver 17 ===\033[0m\n'
        printf '  1) Install\n  2) Uninstall\n  3) Status\n  q) Quit\n\n'
        read -rp "Choice: " opcion
        case "${opcion:-}" in
            1) instalar ;;
            2) desinstalar ;;
            3) estado ;;
            *) aviso "Bye." ;;
        esac
        ;;
    *) morir "usage: $0 [install|uninstall|status]" ;;
esac
