-- monitor-setup-lib.lua - data layer for monitor-setup (no curses / TUI here).
--
-- Reads the connected monitors via 'hyprctl monitors -j' + jq, and reads and
-- writes ~/.local_host_monitors, this machine's LOCAL monitor file (outside the
-- repo). On first run the file is created from the repo template (or with the
-- default fallback), and saving keeps the header + fallback intact and runs
-- 'hyprctl reload' so the profile applies right away.
--
-- Monitors are matched by their physical EDID description ('desc:...'), not by
-- the port, so the same monitor on DP-1, USB-C or HDMI-A-1 always gets its
-- profile; the internal panel is matched the same way. The 'fallback' block
-- covers any monitor without a profile.
--
-- Requires: hyprctl (Hyprland running) and jq.

local lib = {}

-- --------------------------------------------------------------------------
-- Paths
-- --------------------------------------------------------------------------

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function lib.home()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

function lib.config_file()
    return lib.home() .. "/.local_host_monitors"
end

-- Directory of this module file (a required module is never a symlink, so the
-- source path is the real one).
local SRC = debug.getinfo(1, "S").source:gsub("^@", "")
local BIN_DIR = SRC:match("^(.*)/[^/]*$") or "."

function lib.template_file()
    return BIN_DIR .. "/../templates/local_host_monitors"
end

-- Header used to build a valid file from scratch when the repo template is
-- also missing (mirrors the template's layout).
lib.FALLBACK_HEADER = [[-------------------------------------------------------------------------------
-- External monitor profiles by EDID for this machine. LOCAL file, NOT part of
-- the repo: copied from templates/local_host_monitors on first boot and never
-- overwritten again. hyprland.lua reads it on every start and reload.
-- To add a monitor: plug it in and run 'monitor-setup' (or run
-- 'monitor-id --ext' and paste the line by hand).

return {
  fallback = {
    mode     = "preferred",
    position = "auto-right",
    scale    = 1,
  },

]]

-- Everything up to and including the 'external = {' line of the repo template,
-- so the written file keeps the same doc header + fallback.
function lib.default_header()
    local tpl = io.open(lib.template_file(), "r")
    if tpl then
        local text = tpl:read("*a") or ""
        tpl:close()
        local idx = text:find("external%s*=%s*{")
        if idx then
            local nl = text:find("\n", idx)
            if nl then
                return text:sub(1, nl)
            end
            return text .. "\n"
        end
        return text
    end
    return lib.FALLBACK_HEADER
end

-- --------------------------------------------------------------------------
-- Monitor description helpers
-- --------------------------------------------------------------------------

-- Normalize a description to the 'desc:' form used in the profiles.
function lib.norm_desc(description)
    local d = tostring(description or "")
    if d:sub(1, 5) == "desc:" then
        return d
    end
    return "desc:" .. d
end

-- Remove the 'desc:' prefix for display.
function lib.raw_desc(desc)
    return tostring(desc or ""):gsub("^desc:", "")
end

-- Short friendly name for a desc: "desc:Del Inc. P2422H 0x00000000" -> "Del Inc. P2422H".
function lib.display_name(desc)
    local d = lib.raw_desc(desc)
    d = d:gsub("%s+0x[0-9A-Fa-f]+$", ""):gsub("%s+$", "")
    if d == "" then
        d = "External"
    end
    return d
end

-- --------------------------------------------------------------------------
-- Connected monitors (hyprctl)
-- --------------------------------------------------------------------------

function lib.read_monitors()
    local monitors = {}
    local p = io.popen("hyprctl monitors -j | jq -r '.[] | [.name, .description, (.width|tostring), (.height|tostring), (.refreshRate|tostring), (.scale|tostring), (.dpmsStatus|tostring)] | @tsv'")
    if p then
        local out = p:read("*a") or ""
        p:close()
        for line in out:gmatch("[^\n]+") do
            local name, description, width, height, refresh, scale, dpms =
                line:match("^([^\t]*)\t(.*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
            if name then
                table.insert(monitors, {
                    name = name,
                    desc = lib.norm_desc(description or ""),
                    width = tonumber(width) or 0,
                    height = tonumber(height) or 0,
                    refresh = tonumber(refresh) or 0,
                    scale = tonumber(scale) or 1,
                    dpms = (dpms == "true"),
                    internal = name:match("^eDP%-") ~= nil
                        or name:match("^LVDS%-") ~= nil
                        or name:match("^DSI%-") ~= nil,
                })
            end
        end
    end
    return monitors
end

-- "1600x900@60.00" for the mode a monitor is actually driving right now; "no
-- signal" when Hyprland has the port but sends it no mode (width/height 0).
function lib.format_mode(width, height, refresh)
    width, height = tonumber(width) or 0, tonumber(height) or 0
    if width <= 0 or height <= 0 then
        return "no signal"
    end
    if refresh and tonumber(refresh) and tonumber(refresh) > 0 then
        return string.format("%dx%d@%.2f", width, height, tonumber(refresh))
    end
    return string.format("%dx%d", width, height)
end

-- Active mode of a monitor table as returned by lib.read_monitors().
function lib.active_mode(m)
    if not m then
        return "?"
    end
    return lib.format_mode(m.width, m.height, m.refresh)
end

-- Available modes for one monitor, with the trailing 'Hz' stripped.
function lib.available_modes(name)
    local modes, seen = {}, {}
    local p = io.popen("hyprctl monitors -j | jq -r --arg n '" .. tostring(name):gsub("'", "") .. "' '.[] | select(.name==$n) | .availableModes[]'")
    if p then
        local out = p:read("*a") or ""
        p:close()
        for m in out:gmatch("[^\n]+") do
            m = m:gsub("Hz$", "")
            if not seen[m] then
                seen[m] = true
                table.insert(modes, m)
            end
        end
    end
    return modes
end

-- --------------------------------------------------------------------------
-- Profiles (~/.local_host_monitors)
-- --------------------------------------------------------------------------

-- Normalize a workspaces field into a list of positive integers.
local function normalize_workspaces(value)
    local out = {}
    if type(value) ~= "table" then
        return out
    end
    for _, w in ipairs(value) do
        local n = tonumber(w)
        if n and n >= 1 and n == math.floor(n) then
            out[#out + 1] = n
        end
    end
    return out
end

-- Returns profiles, nil on success (an empty list when the file is missing), or
-- nil, error when the file EXISTS but does not load. The caller must NOT
-- overwrite a file that failed to load: the error is surfaced and saving is
-- disabled, so a typo in the local file never eats the saved profiles.
function lib.read_profiles(path)
    path = path or lib.config_file()
    if not file_exists(path) then
        return {}, nil
    end
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, tostring(err)
    end
    local ok, result = pcall(chunk)
    if not ok then
        return nil, tostring(result)
    end
    if result == nil then
        return {}, nil -- empty file: no profiles, but not an error
    end
    if type(result) ~= "table" then
        return nil, "the file must return a table"
    end
    local profiles = {}
    for _, e in ipairs(result.external or {}) do
        if type(e) == "table" and e.desc then
            table.insert(profiles, {
                name = e.name or lib.display_name(e.desc),
                desc = e.desc,
                mode = e.mode or "preferred",
                position = e.position or "auto-right",
                scale = e.scale,
                transform = tonumber(e.transform) or 0,
                disabled = e.disabled and true or false,
                mirror = e.mirror,
                workspaces = normalize_workspaces(e.workspaces),
            })
        end
    end
    return profiles, nil
end

local function lua_quote(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
    return s
end

-- numbers stay unquoted in the file; anything else (e.g. auto) is quoted.
local function serialized_scale(scale)
    if type(scale) == "number" then
        return tostring(scale)
    end
    return '"' .. lua_quote(tostring(scale)) .. '"'
end

-- The extra (optional) fields, written only when they are not the default so a
-- plain profile line stays short: transform, disabled, mirror, workspaces.
local function serialized_extra(p)
    local parts = {}
    local transform = tonumber(p.transform)
    if transform and transform ~= 0 then
        parts[#parts + 1] = "transform = " .. tostring(math.floor(transform))
    end
    if p.disabled then
        parts[#parts + 1] = "disabled = true"
    end
    if p.mirror and tostring(p.mirror) ~= "" then
        parts[#parts + 1] = 'mirror = "' .. lua_quote(tostring(p.mirror)) .. '"'
    end
    if type(p.workspaces) == "table" and #p.workspaces > 0 then
        local ws = {}
        for _, w in ipairs(p.workspaces) do
            ws[#ws + 1] = tostring(math.floor(tonumber(w)))
        end
        parts[#parts + 1] = "workspaces = { " .. table.concat(ws, ", ") .. " }"
    end
    if #parts == 0 then
        return ""
    end
    return ", " .. table.concat(parts, ", ")
end

-- Rewrite the file keeping its header + fallback and writing the 'external'
-- list in the current order. Returns true, or nil + error.
function lib.write_profiles(path, profiles)
    path = path or lib.config_file()

    local prefix
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a") or ""
        f:close()
        local idx = content:find("external%s*=%s*{")
        if idx then
            local nl = content:find("\n", idx)
            prefix = nl and content:sub(1, nl) or (content .. "\n")
        else
            prefix = content
            if not prefix:find("\n$") then
                prefix = prefix .. "\n"
            end
        end
    else
        prefix = lib.default_header()
        if not prefix:find("\n$") then
            prefix = prefix .. "\n"
        end
    end

    local has_open = prefix:match("external%s*=%s*{[^\n]*\n?$") ~= nil
    local out = { prefix }
    if not has_open then
        table.insert(out, "  external = {\n")
    end
    for _, p in ipairs(profiles) do
        table.insert(out, string.format(
            '    { name = "%s", desc = "%s", mode = "%s", position = "%s", scale = %s%s },\n',
            lua_quote(p.name), lua_quote(p.desc), lua_quote(p.mode), lua_quote(p.position),
            serialized_scale(p.scale), serialized_extra(p)))
    end
    table.insert(out, "  },\n")
    table.insert(out, "}\n")

    -- keep one backup of the previous file next to it (cheap undo for a bad save)
    local prev = io.open(path, "r")
    if prev then
        local body = prev:read("*a")
        prev:close()
        local bak = io.open(path .. ".bak", "w")
        if bak then
            bak:write(body or "")
            bak:close()
        end
    end

    local fout, err = io.open(path, "w")
    if not fout then
        return nil, err
    end
    local ok, werr = fout:write(table.concat(out))
    fout:close()
    if not ok then
        return nil, werr
    end
    return true
end

-- --------------------------------------------------------------------------
-- First-run setup + apply
-- --------------------------------------------------------------------------

-- Create the local file if it is missing: copy the repo template, or build a
-- valid file with the default fallback. Returns what happened:
--   "exists" | "template" | "default" | nil+error
function lib.ensure_config_file()
    local path = lib.config_file()
    if file_exists(path) then
        return "exists"
    end
    local tpl = lib.template_file()
    if file_exists(tpl) then
        local f = io.open(tpl, "r")
        local text = (f and f:read("*a")) or ""
        if f then
            f:close()
        end
        local out = io.open(path, "w")
        if out then
            out:write(text)
            out:close()
            return "template"
        end
        return nil, "cannot write " .. path
    end
    local ok, err = lib.write_profiles(path, {})
    if not ok then
        return nil, err
    end
    return "default"
end

-- Apply the config. Returns true, or nil + message.
function lib.hyprctl_reload()
    local p = io.popen("hyprctl reload 2>&1")
    if not p then
        return nil, "cannot run hyprctl"
    end
    local out = p:read("*a") or ""
    local ok = p:close()
    if ok then
        return true
    end
    return nil, out:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

-- Run a Lua snippet through 'hyprctl eval' (used to apply a monitor rule live,
-- for the preview). Returns true, or nil + message.
function lib.hyprctl_eval(code)
    local f = io.popen("hyprctl eval " .. string.format("%q", code) .. " 2>&1")
    if not f then
        return nil, "cannot run hyprctl"
    end
    local out = f:read("*a") or ""
    local ok = f:close()
    if ok and not out:match("^error") and not out:match("unknown request") then
        return true
    end
    return nil, out:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

return lib