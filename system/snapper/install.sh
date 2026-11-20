#!/usr/bin/env bash
# Snapshots btrfs para `ceft-shell snapshots` / `ceft-shell upgrade` (lo llama `ceft-shell system`).
#   sudo bash install.sh <usuario>
# Hace: config de snapper para "/" (si no existe), límites chicos, timer de limpieza, y
# limine-snapper-sync (snapshots en el menú de Limine) si está instalado.
# Es idempotente. No instala paquetes: eso lo hace `ceft-shell pkgs install` (grupo "snapshots").
# DRY_RUN=1 solo imprime lo que haría (no requiere root); LIMINE_CONF=<archivo> cambia el limine.conf a revisar.
set -euo pipefail
DRY="${DRY_RUN:-}"
USER_NAME="${1:-${SUDO_USER:-}}"
[[ -n $USER_NAME ]] || { echo "pasá el usuario"; exit 1; }
if [[ -z $DRY ]]; then [[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }; fi

run() { if [[ -n $DRY ]]; then echo "(dry-run) $*"; else "$@"; fi; }
snap_has() { command -v snapper >/dev/null 2>&1; }

snap_has || { echo "snapper no está instalado: ceft-shell snapshots setup (o ceft-shell pkgs install con el grupo snapshots)"; exit 1; }
fstype=$(findmnt -no FSTYPE / 2>/dev/null || true)
[[ $fstype == btrfs ]] || { echo "/ no es btrfs ($fstype): no hay snapshots posibles"; exit 1; }

# 1. config "root" para /
if snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx root; then
    echo "snapper: config root ya existe"
else
    # snapper no puede crear /.snapshots si ya hay un directorio común ahí
    if [[ -d /.snapshots ]] && ! btrfs subvolume show /.snapshots >/dev/null 2>&1; then
        rmdir /.snapshots 2>/dev/null || { echo "/.snapshots existe y no es un subvolumen ni está vacío: revisalo a mano"; exit 1; }
    fi
    run snapper -c root create-config /
fi

# 2. límites: sin timeline, solo snapshots "number" (pre/post de upgrade), máx. 10
run snapper -c root set-config \
    TIMELINE_CREATE=no TIMELINE_CLEANUP=no TIMELINE_LIMIT_HOURLY=5 \
    NUMBER_CLEANUP=yes NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 NUMBER_MIN_AGE=1800 \
    ALLOW_USERS="$USER_NAME" SYNC_ACL=yes
run systemctl enable --now snapper-cleanup.timer

# 3. limine-snapper-sync
if command -v limine-snapper-sync >/dev/null 2>&1; then
    run systemctl enable --now limine-snapper-sync.service
    conf=${LIMINE_CONF:-}
    if [[ -z $conf ]]; then
        for d in /boot /efi /boot/efi /limine; do [[ -f $d/limine.conf ]] && { conf=$d/limine.conf; break; }; done
    fi
    if [[ -z $conf || ! -r $conf ]]; then
        echo "AVISO: no encontré limine.conf (/boot, /efi, /boot/efi, /limine). Definí ESP_PATH en /etc/default/limine."
    elif ! grep -Eq '^[[:space:]]*/{1,2}Snapshots' "$conf"; then
        echo "AVISO: $conf no tiene la marca de snapshots. Agregá '  //Snapshots' como última línea dentro del bloque"
        echo "       de tu entrada (/Arch Linux ...) y corré: sudo limine-snapper-sync"
    else
        echo "limine.conf listo para snapshots"
    fi
else
    echo "AVISO: limine-snapper-sync no está instalado: los snapshots se crean pero no aparecen en el menú de Limine."
fi
echo "Snapshots listos (config root, límite 10, usuario $USER_NAME). Probá: ceft-shell snapshots list"
