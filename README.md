# ceft-shell

Entorno Hyprland propio: atajos estilo qtile, barra en Quickshell y capturas estilo Omarchy.
Todo se configura desde archivos chicos y versionados. Un solo comando reinstala la máquina entera.

## Instalar en un Arch recién instalado

Un solo comando, con tu usuario normal (no root):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ceftx/ceft-shell/main/boot.sh)
# mínimo y sin preguntas:
# bash <(curl -fsSL https://raw.githubusercontent.com/ceftx/ceft-shell/main/boot.sh) --groups base,desktop -y
```

O a mano: `git clone https://github.com/ceftx/ceft-shell ~/ceft-shell && ~/ceft-shell/install.sh`.

El instalador:

1. Actualiza el sistema e instala `paru`.
2. Instala los paquetes de `packages/*.txt`, más los drivers que detecte (NVIDIA, AMD, microcódigo).
3. Enlaza `config/*` en `~/.config/*` y respalda lo que ya hubiera en `~/.local/state/ceft-shell/backups/`.
4. Restaura los archivos sueltos de `files.txt` (los que reescriben su archivo y rompen symlinks).
5. Habilita los servicios de `services.txt`, pone fish como shell y te agrega al grupo docker.

## Cómo está organizado

```
config/hypr/hyprland.lua      entrada (no tocar)
config/hypr/settings.lua      ← TUS preferencias: apps, layouts, aspecto, teclado, atajos
config/hypr/local.lua         ← solo esta máquina: monitores, dispositivos (no se sube)
config/hypr/ceft/*.lua        núcleo: valores por defecto, atajos, reglas
config/hypr/scripts/          captura y grabación
config/quickshell/            barra
config/ceft-shell/themes/     temas (un JSON alimenta Hyprland, barra y kitty)
packages/*.txt                paquetes por grupo · hardware/ se instala según el equipo
services.txt                  servicios a habilitar
```

### Personalizar atajos sin tocar el núcleo

En `settings.lua` (o en `local.lua`, si es solo para esta máquina):

```lua
binds = {
    ["apps.browser"]      = "$mod + SHIFT + B",  -- cambiar combinación
    ["window.fullscreen"] = false,               -- desactivar
},
extra_binds = {
    { "$mod + O", "obsidian" },                  -- nuevo
},
```

`ceft-shell binds` lista todos los ids. Si un id no existe, Hyprland muestra un aviso.

## Comandos

| Comando | Qué hace |
|---|---|
| `ceft-shell edit [settings\|local\|binds\|bar]` | abre el archivo y valida la config al cerrar |
| `ceft-shell theme [nombre]` | cambia el tema en vivo |
| `ceft-shell save "mensaje"` | valida, hace commit y push |
| `ceft-shell update` | pull + enlaces + migraciones + paquetes nuevos + recarga (en otra máquina) |
| `ceft-shell upgrade` | snapshot pre/post (si hay snapper) + `paru -Syu` + update |
| `ceft-shell snapshots [list\|create <desc>\|setup\|rollback-help]` | snapshots btrfs |
| `ceft-shell migrate [--list\|--dry-run]` | migraciones de config pendientes |
| `ceft-shell secret set\|get\|delete <nombre>` · `secret list` | secretos en el keyring |
| `ceft-shell release [patch\|minor\|major]` | sube `VERSION`, crea el tag y la release en GitHub |
| `ceft-shell rollback <tag>` | vuelve a una versión anterior |
| `ceft-shell pkgs new` | paquetes que instalaste a mano y no están en ninguna lista |
| `ceft-shell pkgs add dev nodejs` | instala el paquete y lo agrega a `packages/dev.txt` |
| `ceft-shell files [status\|push\|pull]` | configs sueltas de `files.txt` (mimeapps, Dolphin, htop, git) que se copian al repo en cada `save` |
| `ceft-shell vpn import <archivo.ovpn>` | importa tu VPN sin autoconectar y apunta el killswitch a ese servidor |
| `ceft-shell doctor` | revisa config, enlaces y paquetes |

Flujo típico: editás (los cambios se aplican al instante porque `~/.config` apunta al repo), después `ceft-shell save` y, en la otra máquina, `ceft-shell update`.

## Temas

Copiá un JSON de `config/ceft-shell/themes/`, cambiale los colores y aplicalo con `ceft-shell theme <nombre>`.
Las claves `color0`-`color15` son la paleta de la terminal; el resto son los colores de la interfaz.

## Robustez

### Snapshots antes de actualizar (btrfs + snapper + Limine)

Opcional, para equipos con `/` en btrfs y Limine. Grupo de paquetes `snapshots` (`snapper`, `snap-pac`,
`inotify-tools`, `limine-snapper-sync` del AUR; compila con gradle, tarda).

```bash
ceft-shell snapshots setup      # instala el grupo y corre system/snapper/install.sh (pide sudo)
```

`system/snapper/install.sh` crea la config `root` de snapper para `/` (sin timeline, máximo 10 snapshots
"number", limpieza automática), habilita `limine-snapper-sync` y revisa que tu `limine.conf` tenga la marca
`//Snapshots` dentro de la entrada del sistema (si falta, te dice qué línea agregar; no toca el bootloader).
Después `ceft-shell upgrade` crea un snapshot `pre` y otro `post` con la descripción "ceft-shell upgrade"
alrededor de `paru -Syu`. Si snapper no está configurado, avisa y sigue sin snapshot.

```bash
ceft-shell snapshots list
ceft-shell snapshots create "antes de probar X"
ceft-shell snapshots rollback-help   # cómo volver atrás desde el menú de Limine
```

### Migraciones de config

Cuando cambia el formato de un archivo de `config/ceft-shell/`, el cambio viaja como un script en
`system/migrations/NNNN-descripcion.sh` (idempotente; declara con `# touches: <ruta>` lo que modifica).
`ceft-shell update` corre las pendientes después del pull, respalda antes lo que tocan en
`~/.local/state/ceft-shell/backups/<fecha>-migrate/` y anota las aplicadas en `~/.local/state/ceft-shell/migrations`.
Si una falla, se detiene y se reintenta en el próximo update.

```bash
ceft-shell migrate --list      # aplicadas y pendientes
ceft-shell migrate --dry-run   # qué haría, sin escribir nada
ceft-shell migrate
```

La 0001 pasa `bar.hiddenTray` de `widgets.json` a `tray.hidden` en `bar.json`.

### Secretos en el keyring

Para no dejar contraseñas en archivos de texto (necesita `libsecret` y un servicio de secretos, `gnome-keyring`):

```bash
ceft-shell secret set SMTP_PASS     # pide el valor sin mostrarlo (o lo lee de stdin)
ceft-shell secret get SMTP_PASS
ceft-shell secret delete SMTP_PASS
ceft-shell secret list              # solo nombres
```

Se guardan con el atributo `service=ceft-shell`. El reporte de uso por email
(`config/quickshell/scripts/email-usage.py`) toma `SMTP_PASS` del entorno o de `~/.claude/email-usage.env`
como siempre y, si no está, del keyring.

## Administrador de tareas, apps ocultas y AppImages

- **Administrador de tareas** (`Ctrl+Shift+Esc`, o `:` → «Administrador de tareas»): ventana Quickshell con procesos
  agrupados por app (expandibles), búsqueda, orden por columna, *Finalizar tarea* (`Supr`, SIGTERM) y *Forzar* (SIGKILL),
  y pestaña de rendimiento (CPU por núcleo, memoria, disco, red, GPU NVIDIA). Datos: `config/quickshell/scripts/taskmgr.py` (psutil).
- **Ocultar apps del launcher** (`SUPER+M`): `Ctrl+H` oculta la seleccionada; el prefijo `!` lista las ocultas y `Enter` la vuelve a mostrar.
  Se guarda en `config/ceft-shell/launcher.json` (se versiona con `ceft-shell save`).
- **AppImages**: `ceft-shell appimage add archivo.AppImage` la mueve a `~/Applications`, la hace ejecutable y la registra con
  su ícono para que salga en el launcher (se abre sin depender de ninguna terminal). Desde el launcher, el prefijo `+` lista las
  AppImages sin registrar de `~/Downloads`/`~/Applications` y `Enter` registra. En Dolphin: clic derecho → *Registrar en el launcher*.
  Para correr una desde terminal sin que muera al cerrarla: `appimage run archivo.AppImage` (log en `~/.local/state/ceft-shell/`).
