#!/usr/bin/env bash
# Configura snapshots de Limine cuando Arch arranca con protocol:efi/UKI.
# Mantiene el UKI original como segunda entrada de respaldo, y sigue generándolo en las actualizaciones.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

. /etc/os-release
[[ ${ID:-} == arch ]] || { echo "Este script es para Arch Linux"; exit 1; }
esp=$(sed -n 's/^ESP_PATH=["\047]\(.*\)["\047]$/\1/p' /etc/default/limine | tail -1)
esp=${esp:-/boot}
conf=${LIMINE_CONF:-$esp/limine.conf}
target=$(sed -n 's/^TARGET_OS_NAME=["\047]\(.*\)["\047]$/\1/p' /etc/default/limine | tail -1)
[[ -f $conf ]] || { echo "No existe $conf. Corré primero system/limine/install.sh"; exit 1; }
[[ -n $target ]] || { echo "Falta TARGET_OS_NAME en /etc/default/limine. Corré primero system/limine/install.sh"; exit 1; }
[[ -f /boot/vmlinuz-linux ]] || { echo "No existe /boot/vmlinuz-linux"; exit 1; }
[[ -f /etc/mkinitcpio.d/linux.preset ]] || { echo "No existe /etc/mkinitcpio.d/linux.preset"; exit 1; }

backup=/var/backups/ceft-shell/limine-$(date +%Y%m%d-%H%M%S)
install -D -m 755 -d "$backup"
cp -a "$conf" /etc/mkinitcpio.d/linux.preset "$backup/"
echo "Respaldos guardados en $backup"

if grep -Eq '^default_image=' /etc/mkinitcpio.d/linux.preset; then
    sed -i 's|^default_image=.*|default_image="/boot/initramfs-linux.img"|' /etc/mkinitcpio.d/linux.preset
else
    sed -i '/^default_uki=/i default_image="/boot/initramfs-linux.img"' /etc/mkinitcpio.d/linux.preset
fi
# Genera initramfs-linux.img y MANTIENE default_uki para que Arch Linux pueda seguir usando el respaldo.
mkinitcpio -p linux
[[ -s /boot/initramfs-linux.img ]] || { echo "No se creó /boot/initramfs-linux.img. La configuración de Limine NO cambió."; exit 1; }

cmdline=$(sed -n 's/^[[:space:]]*cmdline:[[:space:]]*//p' "$conf" | head -1)
[[ -n $cmdline ]] || { echo "No encontré el cmdline actual en $conf"; exit 1; }
entry=$(awk -v target="/$target" '$0==target {on=1} on && /^\/[^/]/ && $0!=target {exit} on' "$conf")
if grep -Eq '^[[:space:]]*protocol:[[:space:]]*linux' <<<"$entry"; then
    echo "La entrada $target ya usa protocol:linux; no se modifica."
else
    python3 "$HERE/convert-linux-entry.py" "$conf" "$target" "$cmdline"
    echo "Limine: Linux separado como entrada principal y UKI como respaldo."
fi
limine-snapper-sync
printf '\nListo. En el próximo arranque aparecen «%s» y «Arch Linux (UKI, respaldo)».\n' "$target"
echo "Si Linux no arranca, elegí el UKI de respaldo."
