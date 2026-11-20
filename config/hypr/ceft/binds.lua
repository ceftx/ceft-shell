-- Atajos por defecto de ceft-shell: estilo qtile (antoniosarosi) + capturas estilo Omarchy.
-- Cada atajo tiene un id. Para cambiarlo o desactivarlo, usá settings.binds:
--   binds = { ["apps.browser"] = "$mod + SHIFT + B", ["window.fullscreen"] = false }
local ceft = require("ceft")
local dsp  = hl.dsp

local function defaults(S)
    local A       = S.apps
    local scripts = "$HOME/.config/hypr/scripts/"

    -- next_layout / prev_layout: recorre settings.layouts
    local layoutIdx = 1
    local function cycleLayout(step)
        return function()
            layoutIdx = (layoutIdx - 1 + step) % #S.layouts + 1
            hl.config({ general = { layout = S.layouts[layoutIdx] } })
            hl.notification.create({ text = "Layout: " .. S.layouts[layoutIdx], duration = 1000 })
        end
    end

    local locked, rep = { locked = true }, { locked = true, repeating = true }

    local B = {
        -- Foco con h/j/k/l y flechas
        { "focus.left",  "$mod + H",     dsp.focus({ direction = "left" }) },
        { "focus.down",  "$mod + J",     dsp.focus({ direction = "down" }) },
        { "focus.up",    "$mod + K",     dsp.focus({ direction = "up" }) },
        { "focus.right", "$mod + L",     dsp.focus({ direction = "right" }) },
        { "focus.left.arrow",  "$mod + left",  dsp.focus({ direction = "left" }) },
        { "focus.right.arrow", "$mod + right", dsp.focus({ direction = "right" }) },
        { "focus.up.arrow",    "$mod + up",    dsp.focus({ direction = "up" }) },
        { "focus.down.arrow",  "$mod + down",  dsp.focus({ direction = "down" }) },

        -- MonadTall: agrandar/achicar master y shuffle
        { "layout.grow",   "$mod + SHIFT + L", dsp.layout("mfact +0.05"), { repeating = true } },
        { "layout.shrink", "$mod + SHIFT + H", dsp.layout("mfact -0.05"), { repeating = true } },
        { "layout.swap.next", "$mod + SHIFT + J", dsp.layout("swapnext") },
        { "layout.swap.prev", "$mod + SHIFT + K", dsp.layout("swapprev") },
        { "layout.next",   "$mod + Tab",         cycleLayout(1) },
        { "layout.prev",   "$mod + SHIFT + Tab", cycleLayout(-1) },

        -- Ventanas
        { "window.float",      "$mod + SHIFT + F", dsp.window.float({ action = "toggle" }) },
        { "window.close",      "$mod + W",         dsp.window.close() },
        { "window.fullscreen", "$mod + F",         dsp.window.fullscreen() },

        -- Monitores
        { "monitor.next", "$mod + period", dsp.focus({ monitor = "+1" }) },
        { "monitor.prev", "$mod + comma",  dsp.focus({ monitor = "-1" }) },

        -- Sesión
        { "session.reload", "$mod + CTRL + R", dsp.exec_cmd("ceft-shell reload || (hyprctl reload; pkill quickshell; quickshell)") },
        { "session.exit",   "$mod + CTRL + Q", dsp.exec_cmd("qs ipc call power request logout") },   -- por PowerGuard: avisa si hay pacman/descargas/grabación

        -- Apps
        { "apps.launcher", "$mod + M",          dsp.exec_cmd(A.launcher) },
        { "overview.toggle", "$mod + O",       dsp.exec_cmd("qs ipc call overview toggle") },
        { "apps.runner",   "$mod + SHIFT + M",  dsp.exec_cmd(A.runner) },
        { "apps.browser",  "$mod + B",          dsp.exec_cmd(A.browser) },
        { "apps.files",    "$mod + E",          dsp.exec_cmd(A.files) },
        { "apps.emoji",    "$mod + SHIFT + E",  dsp.exec_cmd("qs ipc call launcher emoji") },
        { "apps.terminal", "$mod + Return",     dsp.exec_cmd(A.terminal) },
        { "apps.controlcenter", "$mod + T",     dsp.exec_cmd("qs ipc call controlcenter toggle") },
        { "sidebar.toggle",     "$mod + N",     dsp.exec_cmd("qs ipc call sidebar toggle") },
        { "nightlight.on",  "$mod + R",         dsp.exec_cmd("hyprsunset -t " .. S.nightlight) },
        { "nightlight.off", "$mod + SHIFT + R", dsp.exec_cmd("pkill hyprsunset") },

        -- Wallpaper (si el tema es "wallpaper", también cambian los colores)
        { "wall.next",   "$mod + ALT + W",         dsp.exec_cmd("$HOME/.local/bin/ceft-shell wall next") },
        { "wall.random", "$mod + ALT + SHIFT + W", dsp.exec_cmd("$HOME/.local/bin/ceft-shell wall random") },

        -- Portapapeles: SUPER+V abre el historial completo (launcher en modo $);
        -- SUPER+C / SUPER+X copian/cortan en la ventana activa (Ctrl+Insert / Ctrl+X)
        { "clipboard.history", "$mod + V", dsp.exec_cmd("qs ipc call launcher clipboard") },
        { "clipboard.copy",    "$mod + C", dsp.send_shortcut({ mods = "CTRL", key = "Insert" }) },
        { "clipboard.cut",     "$mod + X", dsp.send_shortcut({ mods = "CTRL", key = "X" }) },

        -- Capturas y grabación (estilo Omarchy)
        { "shot.region.edit", "Print",               dsp.exec_cmd(scripts .. "shot region edit") },
        { "shot.region.copy", "SHIFT + Print",       dsp.exec_cmd(scripts .. "shot region copy") },
        { "shot.output.copy", "CTRL + Print",        dsp.exec_cmd(scripts .. "shot output copy") },
        { "rec.region",       "ALT + Print",         dsp.exec_cmd(scripts .. "screenrecord region") },
        { "rec.region.audio", "ALT + SHIFT + Print", dsp.exec_cmd(scripts .. "screenrecord region --audio") },
        { "rec.output",       "CTRL + ALT + Print",  dsp.exec_cmd(scripts .. "screenrecord output") },
        { "colorpicker",      "$mod + Print",        dsp.exec_cmd("hyprpicker -a") },
        -- Atajos de qtile (scrot)
        { "shot.qtile.output", "$mod + S",         dsp.exec_cmd(scripts .. "shot output copy") },
        { "shot.qtile.region", "$mod + SHIFT + S", dsp.exec_cmd(scripts .. "shot region copy") },

        -- Modo juego (sin animaciones/blur/sombras/huecos + no molestar) y terminal desplegable
        { "gamemode.toggle", "$mod + G", dsp.exec_cmd("$HOME/.local/bin/ceft-shell gamemode toggle") },
        { "dropterm.toggle", "$mod + D", dsp.exec_cmd(scripts .. "dropterm") },

        -- Scratchpad
        { "scratch.toggle", "$mod + grave",         dsp.workspace.toggle_special("magic") },
        { "scratch.move",   "$mod + SHIFT + grave", dsp.window.move({ workspace = "special:magic" }) },

        -- Ratón
        { "mouse.ws.next", "$mod + mouse_down", dsp.focus({ workspace = "e+1" }) },
        { "mouse.ws.prev", "$mod + mouse_up",   dsp.focus({ workspace = "e-1" }) },
        { "mouse.drag",    "$mod + mouse:272",  dsp.window.drag(),   { mouse = true } },
        { "mouse.resize",  "$mod + mouse:273",  dsp.window.resize(), { mouse = true } },

        -- Multimedia
        { "media.vol.up",   "XF86AudioRaiseVolume",  dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), rep },
        { "media.vol.down", "XF86AudioLowerVolume",  dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      rep },
        { "media.mute",     "XF86AudioMute",         dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     locked },
        { "media.micmute",  "XF86AudioMicMute",      dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   locked },
        { "media.bright.up",   "XF86MonBrightnessUp",   dsp.exec_cmd("$HOME/.local/bin/ceft-shell brightness +5"), rep },
        { "media.bright.down", "XF86MonBrightnessDown", dsp.exec_cmd("$HOME/.local/bin/ceft-shell brightness -5"), rep },
        { "media.next",  "XF86AudioNext",  dsp.exec_cmd("playerctl next"),       locked },
        { "media.pause", "XF86AudioPause", dsp.exec_cmd("playerctl play-pause"), locked },
        { "media.play",  "XF86AudioPlay",  dsp.exec_cmd("playerctl play-pause"), locked },
        { "media.prev",  "XF86AudioPrev",  dsp.exec_cmd("playerctl previous"),   locked },
    }

    -- Grupos 1-9: ir / mover ventana
    for i = 1, 9 do
        B[#B + 1] = { "ws.focus." .. i, "$mod + " .. i,         dsp.focus({ workspace = i }) }
        B[#B + 1] = { "ws.move." .. i,  "$mod + SHIFT + " .. i, dsp.window.move({ workspace = i }) }
    end

    return B
end

return function(S)
    local function keys(k) return (k:gsub("%$mod", S.mod)) end

    local seen = {}
    for _, b in ipairs(defaults(S)) do
        local id, k, action, opts = b[1], b[2], b[3], b[4]
        seen[id] = true
        local o = S.binds[id]
        if o ~= false then
            if type(o) == "string" then k = o end
            if opts then hl.bind(keys(k), action, opts) else hl.bind(keys(k), action) end
        end
    end

    for id in pairs(S.binds) do
        if not seen[id] then ceft.warn("settings.binds: id desconocido '" .. id .. "'") end
    end

    -- Submap vacío: el Centro de control (Atajos) lo activa mientras captura una combinación,
    -- para que SUPER+W etc. no ejecuten su acción. Salida de emergencia: CTRL + ALT + Escape.
    hl.define_submap("cc-capture", function()
        hl.bind("CTRL + ALT + ESCAPE", dsp.submap("reset"))
    end)

    for _, b in ipairs(S.extra_binds) do
        local action = type(b[2]) == "string" and dsp.exec_cmd(b[2]) or b[2]
        if b[3] then hl.bind(keys(b[1]), action, b[3]) else hl.bind(keys(b[1]), action) end
    end
end
