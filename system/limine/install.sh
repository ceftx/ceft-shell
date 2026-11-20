#!/usr/bin/env bash
# Apunta limine-snapper-sync al directorio real que contiene limine.conf y lo sincroniza.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
conf=${LIMINE_CONF:-}
if [[ -z $conf ]]; then
    for c in /boot/limine.conf /efi/limine.conf /boot/efi/limine.conf /limine/limine.conf; do
        [[ -f $c ]] && conf=$c && break
    done
fi
if [[ -z $conf ]]; then
    conf=$(find /boot -maxdepth 3 -type f -name limine.conf -print -quit 2>/dev/null || true)
fi
[[ -n $conf && -f $conf ]] || { echo "No encontré limine.conf; pasa LIMINE_CONF=/ruta/al/limine.conf"; exit 1; }
esp=$(dirname "$conf")
if [[ -f /etc/default/limine ]]; then
    cp -a /etc/default/limine "/etc/default/limine.ceft-backup-$(date +%Y%m%d-%H%M%S)"
    sed -i '/^[[:space:]]*ESP_PATH=/d' /etc/default/limine
fi
install -D -m 644 /dev/null /etc/default/limine
printf 'ESP_PATH="%s"\n' "$esp" >> /etc/default/limine
printf 'ESP_PATH="%s" escrito en /etc/default/limine\n' "$esp"
limine-snapper-sync
