-- Utilidades compartidas: carga de settings, local.lua y tema.
local M = {}

local HOME = os.getenv("HOME") or ""
M.theme_file = HOME .. "/.config/ceft-shell/theme.json"

local function warn(msg)
    print("[ceft-shell] " .. msg)
    pcall(function() hl.notification.create({ text = "ceft-shell: " .. msg, duration = 8000 }) end)
end
M.warn = warn

-- Mezcla profunda: las tablas con claves se combinan; las listas
-- ({ "a", "b" }) y los valores simples se reemplazan.
function M.merge(base, over)
    if type(base) ~= "table" or type(over) ~= "table" then return over end
    if #base > 0 or #over > 0 then return over end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over) do out[k] = M.merge(out[k], v) end
    return out
end

local local_module
M.overrides_file = HOME .. "/.config/ceft-shell/overrides.json"

-- Orden: settings.lua (versionado) → overrides.json (Centro de control) → local.lua (esta máquina)
function M.load_settings()
    local settings = require("settings")
    local okj, over = pcall(require("ceft.json").read, M.overrides_file)
    if not okj then
        warn("overrides.json inválido, lo ignoro: " .. tostring(over))
    elseif type(over) == "table" then
        settings = M.merge(settings, over)
    end
    local ok, mod = pcall(require, "local")
    if ok and type(mod) == "table" then
        local_module = mod
        settings = M.merge(settings, mod.settings or {})
    elseif not ok and not tostring(mod):find("module 'local' not found", 1, true) then
        warn("error en local.lua: " .. tostring(mod))
    end
    return settings
end

function M.run_local_setup(settings)
    if local_module and type(local_module.setup) == "function" then
        local ok, err = pcall(local_module.setup, settings)
        if not ok then warn("error en local.lua setup(): " .. tostring(err)) end
    end
end

-- Lector de JSON plano ({"clave": "valor" | número}), suficiente para los temas.
function M.read_flat_json(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    local t = {}
    for k, v in s:gmatch('"([%w_]+)"%s*:%s*"([^"]*)"') do t[k] = v end
    for k, v in s:gmatch('"([%w_]+)"%s*:%s*(%-?[%d%.]+)') do t[k] = tonumber(v) end
    return t
end

-- Tokyo Night por si falta theme.json
local fallback = {
    background = "#1a1b26", foreground = "#a9b1d6", accent = "#7aa2f7",
    accent2 = "#7dcfff", border = "#3b4261", shadow = "#1a1a1a",
}

function M.load_theme()
    local t = M.read_flat_json(M.theme_file)
    if not t then
        warn("no se encontró " .. M.theme_file .. ", uso colores por defecto")
        t = {}
    end
    return M.merge(fallback, t)
end

-- "#7aa2f7" + "ee" → "rgba(7aa2f7ee)"
function M.rgba(hex, alpha)
    return "rgba(" .. (hex:gsub("#", "")) .. (alpha or "ff") .. ")"
end

return M
