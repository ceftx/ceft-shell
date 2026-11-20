#!/usr/bin/env bash
# Acceso DDC/CI para `ceft-shell brightness` (lo llama `ceft-shell system`).
#   sudo bash install.sh <usuario>
# Hace: módulo i2c-dev al arranque y ahora, grupo "i2c", regla udev (grupo + uaccess) para /dev/i2c-*.
# DDC_ROOT=<dir> escribe los archivos bajo <dir> y no toca el sistema (para probar).
set -euo pipefail
ROOT="${DDC_ROOT:-}"
if [[ -z $ROOT ]]; then
    [[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
fi
USER_NAME="${1:-${SUDO_USER:-}}"
[[ -n $USER_NAME ]] || { echo "pasá el usuario"; exit 1; }

install -d "$ROOT/etc/modules-load.d" "$ROOT/etc/udev/rules.d"
echo i2c-dev > "$ROOT/etc/modules-load.d/i2c-dev.conf"
# Grupo i2c para sesiones que no son "uaccess" (ssh, tty); uaccess da acceso inmediato a la sesión gráfica
cat > "$ROOT/etc/udev/rules.d/45-ceft-i2c.rules" <<'RULE'
# ceft-shell: acceso a los buses I2C para ddcutil (brillo de monitores por DDC/CI)
KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660", TAG+="uaccess"
RULE

if [[ -n $ROOT ]]; then echo "(prueba) archivos escritos bajo $ROOT"; exit 0; fi

modprobe i2c-dev
getent group i2c >/dev/null || groupadd -r i2c
id -nG "$USER_NAME" | grep -qw i2c || usermod -aG i2c "$USER_NAME"
udevadm control --reload
udevadm trigger --subsystem-match=i2c-dev --action=add
echo "DDC/CI listo: módulo i2c-dev cargado, regla udev y grupo i2c (usuario $USER_NAME)."
echo "Si 'ceft-shell brightness get' aún da 'sin permiso', cerrá sesión y volvé a entrar (grupo i2c)."
