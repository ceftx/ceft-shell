# Roadmap de ceft-shell

Funciones elegidas tras revisar end-4, end4-pC, HyDE, Omarchy, ML4W, JaKooLit, caelestia y Cozytile.
Criterio: alto valor para el uso diario, todo local (sin servicios externos), con el estilo de ceft-shell.
Esfuerzo: S chico · M mediano · L grande. Origen entre paréntesis.

## Hecho
- [x] Config Hyprland en Lua modular (settings.lua → overrides.json → local.lua) y CLI `ceft-shell`
- [x] Instalador con paquetes por grupo, detección de hardware, killswitch VPN y Claude Code
- [x] Wallpaper con awww + colores Material You (matugen) en barra, Hyprland, kitty y hyprlock
- [x] Barra estilo end-4 sin cajas, popups pegados, widgets de escritorio
- [x] Centro de control (apariencia, escritorio, ventanas, atajos, sistema) · SUPER+T
- [x] hyprlock + hypridle (sin bloquear con pantalla completa)
- [x] Launcher en Quickshell (apps, `=` calculadora, `>` comandos, `:` acciones) · SUPER+M

## Hecho · Fase 6: personalización estilo end4-pC
- [x] Barra configurable por chips (izquierda/centro/derecha), posición arriba/abajo, estilos, autohide
- [x] Módulos nuevos: media, velocidad de red, actualizaciones, distribución de teclado, utilidades
- [x] Páginas Rápido, Barra, Interfaz, Hyprland (monitores con "¿Mantener?"), Servicios, Perfil
- [x] Presets: `ceft-shell preset save|load|list|delete`
- [x] Rotación automática de wallpaper y transición configurable

## Etapa 1 · Rápidas (S, en paralelo) · hecha
- [x] Indicador de privacidad: micrófono en uso / pantalla compartida (end4-pC `services/Privacy.qml`)
- [x] Aviso antes de apagar si pacman/paru corre o hay descargas a medias (end4-pC `SessionWarnings.qml`)
- [x] Modo juego: sin animaciones/blur/sombras + no molestar, con atajo (HyDE, caelestia)
- [x] Terminal desplegable con atajo (JaKooLit `Dropterminal.sh`)
- [x] Brillo real del monitor por DDC/CI (falta instalar ddcutil y `ceft-shell system`) — `ddcutil`, `i2c-dev` (caelestia)
- [x] Colores del wallpaper en VS Code (plantilla matugen) (end4-pC, HyDE)

## Terminal: fish + starship de ceftx/dotfiles
- [x] config.fish adaptado (env, PATH, Java, aliases), fzf.fish + funciones ff*, colores, starship.toml
- [x] Instalar herramientas: fzf, fd, bat, eza, tmux, neovim (`ceft-shell pkgs install`)

## Etapa 2 · Notificaciones y control (M) · hecha
- [x] Servidor de notificaciones en Quickshell (reemplaza dunst): popups, historial, no leídas, no molestar (end4-pC)
- [x] OSD de volumen y brillo (end4-pC `onScreenDisplay/`)
- [x] Panel de ajustes rápidos estilo Android + mezclador de volumen por app + luz nocturna con horario (end4-pC `sidebarRight/`)

## Etapa 2.5 · Barra vertical (M/L) · hecha
- [x] bar.json "position": "left" | "right": módulos en columna (íconos, workspaces verticales, reloj apilado)
- [x] Popups y panel lateral que se abren al costado de la barra; exclusiveZone lateral
- [x] Páginas Barra/Rápido del Centro de control con Izquierda/Derecha

## Etapa 3 · Productividad (M)
- [x] **Historial del portapapeles estilo Omarchy** (SUPER+V) — `cliphist`, `wtype`
  - Omarchy: Walker + Elephant, SUPER+CTRL+V abre el modo portapapeles, prefijo `$` en el launcher
    (`default/hypr/bindings/clipboard.conf`, `config/walker/config.toml`)
  - ceft-shell: mismo flujo en nuestro launcher (sin Walker): SUPER+CTRL+V, prefijo `$`, texto e imágenes
    con vista previa, búsqueda, fijados, borrar; `wl-paste --watch cliphist store` en autostart
  - Copiar/pegar universal de Omarchy: SUPER+C / SUPER+V / SUPER+X → Ctrl+Insert / Shift+Insert / Ctrl+X a la
    ventana activa (`sendshortcut`), funciona igual en terminal y en apps
- [x] **Capturas (pedido del usuario)** · Selector de región unificado: copiar, editar, OCR, QR, grabar — `tesseract-data-spa/eng`, `zxing-cpp` (end4-pC `regionSelector/`; sin Google Lens)
- [x] Selector de emojis y glifos como prefijo del launcher (end4-pC, HyDE)

## Etapa 4 · Overview (L)
- [x] Vista de workspaces con miniaturas en vivo, arrastrar ventanas y búsqueda (end4-pC `modules/ii/overview/`)

## Etapa 5 · Robustez
- [x] Snapshots antes de `ceft-shell upgrade` (activar: `ceft-shell snapshots setup`) — btrfs + `snapper` + `limine-snapper-sync` (ML4W `ml4w-snapshot`)
- [x] Migraciones versionadas de config en `ceft-shell update` (HyDE `Scripts/migrations/`)
- [x] Secretos en el keyring (SMTP del reporte de uso, API keys) — `libsecret` (end4-pC `KeyringStorage.qml`)

## Ideas para después
- Barra vertical (izquierda/derecha)
- Chat con IA en sidebar solo con Ollama local
- Perfiles de trabajo (bundle de animaciones/blur/opacidad) (HyDE workflows)
- Shader anti-encandilamiento nocturno (end4-pC)
- Hoja de atajos visual (end-4 cheatsheet)
- Webapps con perfil aislado del navegador (end4-pC)

## Descartado (privacidad o poco valor)
- Ubicación por GPS/geoclue, Google Lens, traductor con Google, Shazam, letras online, galerías de wallpapers
  online, chat con IA en la nube, fútbol/ESPN
- Dock (poco uso en tiling), wallpaper en video (GPU), teclado en pantalla, contenido anime/booru
