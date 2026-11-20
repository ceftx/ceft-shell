-- Reglas de ventanas. Agregá las tuyas en local.lua setup() o acá si son para todas tus máquinas.
return function(S)
    -- Ignorar pedidos de maximizar de las apps
    hl.window_rule({
        name  = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    })

    -- Arreglo de arrastre en XWayland
    hl.window_rule({
        name  = "fix-xwayland-drags",
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
    })

    -- Pantalla completa (videos, juegos) = no está inactivo: hypridle no bloquea ni apaga la pantalla
    hl.window_rule({
        name  = "idle-inhibit-fullscreen",
        match = { class = ".*" },
        idle_inhibit = "fullscreen",
    })

    hl.window_rule({
        name  = "move-hyprland-run",
        match = { class = "hyprland-run" },
        move  = "20 monitor_h-120",
        float = true,
    })

    -- Vidrio de la barra de Quickshell: blur real en barra, popups y ventana de red.
    -- (el scrim a pantalla completa NO entra: quickshell-scrim / -netsettings-scrim)
    hl.layer_rule({
        name  = "quickshell-glass",
        match = { namespace = "^quickshell-(bar|popup|netsettings|desktop|controlcenter|launcher|overview|sidebar|notif|osd)$" },
        blur  = true,
        ignore_alpha = 0.2,
    })

    -- Administrador de tareas (Quickshell, taskmgr/TaskManager.qml): ventana flotante centrada
    hl.window_rule({
        name  = "ceft-taskmgr",
        match = { title = "^Administrador de tareas$" },
        float = true,
        size  = "1040 700",
        center = true,
    })

    -- Terminal desplegable (SUPER+D, scripts/dropterm): kitty "ceft-dropterm" en el workspace
    -- especial "dropterm", flotante, 70% x 45%, centrada arriba, con slide desde arriba.
    -- "silent": al crearse no roba el foco; el script la muestra después.
    hl.window_rule({
        name  = "ceft-dropterm",
        match = { class = "^ceft-dropterm$" },
        float = true,
        workspace = "special:dropterm silent",
        size  = "(monitor_w*0.7) (monitor_h*0.45)",
        move  = "(monitor_w*0.15) 56",
        animation = "slide top",
    })
end
