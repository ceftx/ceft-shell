-- Procesos al iniciar Hyprland.
-- Ajustes del historial para clip-store (se reescriben en cada carga/recarga de la config).
local function write_clip_conf(C)
    local home = os.getenv("HOME") or ""
    local dir = home .. "/.local/state/ceft-shell"
    os.execute("mkdir -p '" .. dir .. "'")
    local f = io.open(dir .. "/clip.conf", "w")
    if not f then return end
    local apps = {}
    for _, a in ipairs(C.password_apps or {}) do apps[#apps + 1] = tostring(a):gsub("[^%w%s._-]", "") end
    f:write("max_items=" .. math.floor(tonumber(C.max_items) or 1000) .. "\n")
    f:write("block=" .. table.concat(apps, ",") .. "\n")
    f:close()
end

return function(S)
    local C = S.clipboard or {}
    if C.enabled ~= false then write_clip_conf(C) end
    hl.on("hyprland.start", function()
        if S.wallpaper.enabled then hl.exec_cmd("$HOME/.local/bin/ceft-shell wall restore") end
        hl.exec_cmd("pidof hypridle || hypridle")   -- bloqueo/apagado por inactividad (ceft-shell idle)
        if S.apps.bar and S.apps.bar ~= "" then hl.exec_cmd(S.apps.bar) end
        -- historial del portapapeles: vigilantes de wl-paste (idempotente; no hace nada sin cliphist)
        if C.enabled ~= false then hl.exec_cmd("$HOME/.config/hypr/scripts/clip-store watch") end
        for _, cmd in ipairs(S.autostart) do hl.exec_cmd(cmd) end
    end)
end
