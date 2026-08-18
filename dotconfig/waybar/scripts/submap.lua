#!/usr/bin/lua
--
-- Módulo custom/submap de waybar.
--
-- En la barra: un icono que dice QUÉ modo modal está activo -- una regla para resize,
-- un monitor para monitor -- y nada cuando no hay ninguno. En el tooltip, la palabra y
-- las teclas de ese modo, que es lo que uno olvida justo cuando entra.
--
-- Reemplaza al módulo estándar 'hyprland/submap', que funcionaba pero sólo sabe mostrar
-- UN texto fijo para todos los submapas: no soporta 'format-icons' (probado -- con
-- "format": "{icon}" el texto sale vacío y waybar esconde el módulo entero) y su
-- 'format' admite como único valor variable '{}', el nombre del submapa. Con él, lo más
-- lejos que se llegaba era el mismo icono para los dos modos y el color como distinción.
--
-- NO hace polling ni necesita que nadie le avise: se cuelga del socket de EVENTOS de
-- Hyprland (.socket2.sock), que emite 'submap>>nombre' al entrar y 'submap>>' (vacío) al
-- salir. Esto importa más de lo que parece. La alternativa era que hyprland.lua mandara
-- una señal en cada entrada y cada salida de submapa, y las salidas son varias -- Return
-- y Escape de 'resize', Return y Escape de 'monitor', que además salen por un exec_cmd
-- con sort-workspaces adentro. Olvidarse de una sola deja el icono clavado mostrando un
-- modo del que ya saliste. Escuchando el evento no hay nada que recordar, y hyprland.lua
-- no se toca.
--
-- Waybar lo corre en modo continuo: sin 'interval', leyendo una línea JSON por evento. Si
-- Hyprland se reinicia, el socket muere, este script termina y el 'restart-interval' del
-- config lo vuelve a levantar (verificado).

local dkjson = require("dkjson")
local socket = require("socket")
local unix = require("socket.unix")

-- Icono por modo. El default cubre cualquier submapa que se agregue a hyprland.lua sin
-- pasar por acá: un teclado genérico, que al menos avisa que hay un modo activo. Los
-- glifos son de "Symbols Nerd Font", que viene versionada en config_files/fonts, y van
-- por codepoint y no como carácter suelto para que se vean en cualquier editor.
-- Los bytes UTF-8 se calculan de los codepoints:
--   U+F0A68 = nf-md-resize  -> F3 B0 A9 A8
--   U+F0379 = nf-md-monitor -> F3 B0 8D B9
--   U+F030C = nf-md-keyboard -> F3 B0 8C 8C
local ICONOS = {
    resize  = "\243\176\169\168",  -- nf-md-resize  U+F0A68
    monitor = "\243\176\141\185",  -- nf-md-monitor U+F0379
}
local ICONO_DEFAULT = "\243\176\140\140"  -- nf-md-keyboard U+F030C

-- Las teclas de cada modo, que son las que uno no se acuerda al entrar. Salen de las
-- definiciones de submapa de hyprland.lua; si allá cambian los binds, acá también.
local AYUDAS = {
    resize  = "resize mode: H/L width, I/J height. Enter or Esc to exit",
    monitor = "monitor mode: H/L/I/K or arrows move the workspace. Enter or Esc to exit",
}


local function emitir(nombre)
    -- Una línea JSON por evento.
    --
    -- Un texto vacío hace que waybar esconda el módulo entero, que es justo lo que se
    -- quiere fuera de un submapa: ni icono, ni pastilla, ni hueco. Es el mismo patrón que
    -- custom/swap y custom/rclone usan en un equipo que no los tiene.
    --
    -- El 'class' es lo que style.css usa para pintar la pastilla de cada modo.
    --
    -- dkjson.encode produce UTF-8 crudo (equivalente a ensure_ascii=False en Python):
    -- los glifos Nerd Font salen como bytes reales, no como surrogate pairs.
    nombre = (nombre or ""):match("^%s*(.-)%s*$")
    local salida
    if nombre == "" or nombre == "default" then
        salida = { text = "", class = "", tooltip = "" }
    else
        salida = {
            text = ICONOS[nombre] or ICONO_DEFAULT,
            class = nombre,
            tooltip = AYUDAS[nombre] or (nombre .. " mode. Enter or Esc to exit"),
        }
    end
    io.write(dkjson.encode(salida) .. "\n")
    io.flush()
end


local function submap_actual()
    -- Estado inicial: si waybar arranca (o se recarga con SIGUSR2) mientras hay un
    -- submapa activo, sin esto el módulo quedaría vacío hasta el próximo evento.
    local h = io.popen("hyprctl submap 2>/dev/null")
    if not h then return "" end
    local r = h:read("*a")
    h:close()
    return (r or ""):match("^%s*(.-)%s*$")
end


local function main()
    emitir(submap_actual())

    local runtime = os.getenv("XDG_RUNTIME_DIR") or ""
    local firma   = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""
    if runtime == "" or firma == "" then
        return 0
    end
    local ruta = runtime .. "/hypr/" .. firma .. "/.socket2.sock"

    local sock, err = unix()
    if not sock then return 0 end
    local ok, err = sock:connect(ruta)
    if not ok then
        sock:close()
        -- Sin socket no hay nada que escuchar. Se sale en silencio y con estado 0: el
        -- módulo ya emitió el estado inicial, y el 'restart-interval' reintentará.
        return 0
    end

    -- 'receive(N)' de LuaSocket NO es como recv(N) de Python: no vuelve con lo que haya
    -- disponible, bloquea hasta juntar exactamente N bytes. Con eventos chicos como
    -- 'submap>>resize\n' eso nunca pasa y el módulo queda mudo aunque el evento haya
    -- llegado (verificado: 'ok' de hyprctl dispatch y silencio total del lector). Como
    -- Hyprland separa cada evento con '\n', pedir una línea a la vez ('*l') es lo que
    -- corresponde: vuelve apenas hay una completa, y nil cuando el socket se cierra.
    while true do
        local linea = sock:receive("*l")
        if not linea then
            break  -- Hyprland se fue: que waybar vea EOF y relance el script.
        end
        if linea:sub(1, 8) == "submap>>" then
            emitir(linea:sub(9))
        end
    end
    sock:close()
    return 0
end


-- Waybar cerró el pipe o mató el proceso: es la salida normal, no un error.
local ok, err = pcall(function() os.exit(main()) end)
if not ok then
    os.exit(0)
end
