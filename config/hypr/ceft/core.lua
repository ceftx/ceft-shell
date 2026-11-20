-- Monitores por defecto, entorno, aspecto, animaciones y layouts.
local ceft = require("ceft")

return function(S, T)
    -- Monitor genérico; los específicos van en local.lua
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

    -- Monitores del Centro de control / settings (después del genérico, antes de local.lua)
    for _, m in ipairs(S.monitors or {}) do
        if type(m) == "table" and m.output and m.output ~= "" then
            hl.monitor({
                output   = m.output,
                mode     = m.mode or "preferred",
                position = m.position or "auto",
                scale    = m.scale or "auto",
            })
        end
    end

    for k, v in pairs(S.env) do hl.env(k, v) end

    -- Carpetas que leen los scripts de captura/grabación
    local function expand(p) return (p:gsub("^~", os.getenv("HOME") or "~")) end
    local P = S.paths or {}
    if type(P.screenshots) == "string" and P.screenshots ~= "" then hl.env("SCREENSHOT_DIR", expand(P.screenshots)) end
    if type(P.recordings)  == "string" and P.recordings  ~= "" then hl.env("SCREENRECORD_DIR", expand(P.recordings)) end
    -- Transición del wallpaper (la usa `ceft-shell wall`)
    local W = S.wallpaper or {}
    if type(W.transition) == "string" and W.transition ~= "" then hl.env("CEFT_WALL_TRANSITION", W.transition) end

    local L = S.look
    hl.config({
        general = {
            gaps_in     = L.gaps_in,
            gaps_out    = L.gaps_out,
            border_size = L.border_size,
            col = {
                active_border   = { colors = { ceft.rgba(T.accent, "ee"), ceft.rgba(T.accent2, "ee") }, angle = 45 },
                inactive_border = ceft.rgba(T.border, "aa"),
            },
            resize_on_border = false,
            allow_tearing    = false,
            layout           = S.layouts[1],
        },

        decoration = {
            rounding       = L.rounding,
            rounding_power = 2,
            active_opacity   = L.active_opacity,
            inactive_opacity = L.inactive_opacity,
            shadow = {
                enabled      = L.shadow,
                range        = 4,
                render_power = 3,
                color        = ceft.rgba(T.shadow, "ee"),
            },
            blur = {
                enabled  = L.blur,
                size     = 7,
                passes   = 3,
                vibrancy = 0.1696,
            },
        },

        animations = { enabled = L.animations },

        render = {
            cm_auto_hdr       = S.display.auto_hdr,
            send_content_type = S.display.send_content_type,
        },

        dwindle   = {
            preserve_split = S.dwindle.preserve_split,
            smart_split    = S.dwindle.smart_split,
            force_split    = S.dwindle.force_split,
        },
        master    = {                                  -- new_status "slave": como MonadTall
            new_status  = S.master.new_status,
            orientation = S.master.orientation,
            mfact       = S.master.mfact,
        },
        scrolling = { fullscreen_on_one_column = true },

        misc = {
            -- awww dibuja encima; esto queda de respaldo si no está instalado
            force_default_wallpaper = -1,
            disable_hyprland_logo   = false,
            vrr                     = S.display.vrr,
        },

        layers = {
            allow_new_top_layers_over_existing_fullscreen = true,
        },
    })

    -- Curvas y animaciones (las del ejemplo oficial)
    hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
    hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
    hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
    hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
    hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
    hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

    hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
    hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
    hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
    hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
    hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
    hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
    hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
    hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

    -- "Smart gaps": sin huecos ni borde con una sola ventana
    if L.smart_gaps then
        hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
        hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
        hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
        hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })
    end
end
