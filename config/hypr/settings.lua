-- ┌─────────────────────────────────────────────────────────────┐
-- │ ceft-shell · tus preferencias                              │
-- │ Todo lo de acá queda versionado en el repo.                │
-- │ Para algo solo de esta máquina, usá local.lua              │
-- │ (copiá local.example.lua).                                 │
-- └─────────────────────────────────────────────────────────────┘
return {
    -- Tecla principal. En los atajos se escribe "$mod".
    mod = "SUPER",

    apps = {
        terminal = "kitty",
        browser  = "brave",
        files    = "dolphin",
        -- Launcher propio (Quickshell). Para volver a wofi:
        --   launcher = "pkill wofi || wofi --show drun"
        --   runner   = "pkill wofi || wofi --show run"
        launcher = "qs ipc call launcher toggle",      -- SUPER+M
        runner   = "qs ipc call launcher run",         -- SUPER+SHIFT+M
        bar      = "quickshell",
    },

    -- SUPER+Tab / SUPER+SHIFT+Tab recorren esta lista (el primero es el de inicio).
    -- Opciones: "master" (MonadTall de qtile), "dwindle", "scrolling"
    layouts = { "master", "dwindle" },

    look = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        rounding    = 10,
        blur        = true,
        shadow      = true,
        animations  = true,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        smart_gaps  = false,   -- sin huecos ni borde cuando hay una sola ventana
    },

    input = {
        kb_layout      = "us",
        kb_variant     = "altgr-intl",   -- AltGr + vocal = á é í ó ú, AltGr+n = ñ
        kb_options     = "",
        follow_mouse   = 1,
        sensitivity    = 0,
        natural_scroll = false,
        workspace_swipe_fingers = 3,
        repeat_delay   = 600,    -- ms hasta que una tecla empieza a repetirse
        repeat_rate    = 25,     -- repeticiones por segundo
        numlock_by_default = false,
    },

    -- Monitores extra (después del genérico; local.lua puede pisarlos). Lista de:
    --   { output = "DP-1", mode = "2560x1440@200", position = "0x0", scale = 1 }
    monitors = {},

    -- Layouts: ajustes finos de cada uno
    dwindle = { preserve_split = true, smart_split = false, force_split = 0 },
    master  = { new_status = "slave", orientation = "left", mfact = 0.55 },

    -- Carpetas de capturas y grabaciones (se expande ~)
    paths = {
        screenshots = "~/Pictures/Screenshots",
        recordings  = "~/Videos/Screenrecordings",
    },

    display = {
        -- 0 = no pasar a HDR/gama amplia al poner algo en pantalla completa.
        -- En 1 la pantalla se queda 2-3 s en negro mientras el monitor cambia de modo.
        auto_hdr          = 0,
        send_content_type = false,   -- no avisar al monitor del tipo de contenido (evita resincronizar)
        vrr               = 0,       -- 0 off · 1 siempre · 2 solo en pantalla completa
    },

    -- Wallpaper con awww (carpeta: ~/Pictures/Wallpapers o $CEFT_WALL_DIR).
    -- `ceft-shell theme wallpaper` hace que los colores salgan del fondo.
    wallpaper = {
        enabled = true,   -- false = fondo por defecto de Hyprland
        interval_min = 0, -- > 0: rota el wallpaper cada N minutos (lo hace Quickshell)
        transition   = "grow",  -- tipo de transición de awww (grow, wipe, fade, outer, center, any, random…)
    },

    -- Temperatura de color de la luz nocturna (SUPER+R)
    nightlight = 2400,

    env = {
        XCURSOR_SIZE    = "24",
        HYPRCURSOR_SIZE = "24",
    },

    -- Historial del portapapeles (SUPER+V). Necesita los paquetes cliphist y wl-clipboard.
    -- Nunca guarda contraseñas: ignora copias marcadas por gestores (x-kde-passwordManagerHint)
    -- y copias hechas con una de estas apps en primer plano (class o título, sin mayúsculas).
    clipboard = {
        enabled   = true,
        max_items = 1000,
        password_apps = { "keepass", "keepassxc", "bitwarden", "1password", "lastpass", "dashlane", "enpass", "proton pass", "nordpass" },
    },

    -- Programas que se abren al iniciar Hyprland (además de apps.bar)
    autostart = {
        -- "nm-applet",
    },

    -- Cambiar o desactivar atajos por su id (la lista completa está en
    -- ceft/binds.lua, o con `ceft-shell binds`):
    --   ["apps.browser"]      = "$mod + SHIFT + B",   -- otra combinación
    --   ["window.fullscreen"] = false,                -- desactivar
    binds = {},

    -- Atajos nuevos: { teclas, comando o dispatcher, opciones? }
    --   { "$mod + O", "obsidian" },
    --   { "$mod + CTRL + L", "hyprlock" },
    extra_binds = {},
}
