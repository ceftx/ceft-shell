-- ┌─────────────────────────────────────────────────────────────┐
-- │ ceft-shell · punto de entrada de Hyprland                  │
-- │                                                             │
-- │ No edites este archivo para personalizar:                   │
-- │   settings.lua → tus preferencias (versionadas en el repo)  │
-- │   local.lua    → solo esta máquina (monitores, dispositivos)│
-- │   ceft/*.lua   → el núcleo; cambialo solo para cambiar los  │
-- │                  valores por defecto del entorno            │
-- └─────────────────────────────────────────────────────────────┘

-- `hyprctl reload` reutiliza el estado de Lua: sin esto, require() devuelve los módulos
-- cacheados y los cambios en ceft/*.lua, settings.lua o local.lua no se aplican.
for name in pairs(package.loaded) do
    if name == "ceft" or name:match("^ceft%.") or name == "settings" or name == "local" then
        package.loaded[name] = nil
    end
end

local ceft     = require("ceft")
local settings = ceft.load_settings()
local theme    = ceft.load_theme()

require("ceft.core")(settings, theme)
require("ceft.input")(settings)
require("ceft.binds")(settings)
require("ceft.rules")(settings)
require("ceft.autostart")(settings)

-- Último paso: ajustes libres de local.lua (llamadas hl.* directas)
ceft.run_local_setup(settings)
