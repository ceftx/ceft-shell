-- Copiá este archivo a local.lua (o corré `ceft-shell local`).
-- local.lua NO se sube al repo: es para lo que solo aplica a esta máquina.
return {
    -- Se mezcla encima de settings.lua (mismas claves)
    settings = {
        -- look = { gaps_out = 10 },
        -- apps = { browser = "firefox" },
        -- binds = { ["apps.files"] = false },
    },

    -- Llamadas hl.* libres. Se ejecuta al final de la config.
    setup = function(settings)
        -- Monitores: `hyprctl monitors` para ver los nombres
        -- hl.monitor({ output = "DP-1",     mode = "2560x1440@144", position = "0x0",    scale = 1 })
        -- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",  position = "2560x0", scale = 1 })

        -- Dispositivos: `hyprctl devices` para ver los nombres
        -- hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

        -- NVIDIA (si tenés problemas con video acelerado o parpadeos):
        -- hl.env("LIBVA_DRIVER_NAME", "nvidia")
        -- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    end,
}
