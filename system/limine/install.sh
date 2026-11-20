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

# El nombre por defecto viene de /etc/os-release, pero la entrada de Arranque puede ser personalizada.
# Si hay un único sistema raíz en limine.conf, lo usamos (no elegimos automáticamente entre varios).
if ! grep -Eq '^[[:space:]]*TARGET_OS_NAME=' /etc/default/limine /etc/limine-snapper-sync.conf 2>/dev/null \
   && ! grep -Eq '^[[:space:]]*comment:[[:space:]]*machine-id=' "$conf"; then
    entries=()
    while IFS= read -r line; do
        name=${line#/}
        [[ $name == /* ]] && continue   # entradas //kernel, no sistemas
        case ${name,,} in snapshots|backup*) continue ;; esac
        entries+=("$name")
    done < <(grep -E '^[[:space:]]*/[^[:space:]/]' "$conf" || true)
    if [[ ${#entries[@]} -eq 1 ]]; then
        printf 'TARGET_OS_NAME="%s"\n' "${entries[0]}" >> /etc/default/limine
        printf 'TARGET_OS_NAME="%s" detectado en limine.conf\n' "${entries[0]}"
    elif [[ ${#entries[@]} -gt 1 ]]; then
        printf 'Hay varias entradas de sistema: %s\n' "${entries[*]}" >&2
        echo 'Agregá TARGET_OS_NAME="nombre" en /etc/default/limine y volvé a ejecutar este script.' >&2
        exit 2
    fi
fi
if ! limine-snapper-sync; then
    if grep -Eq '^[[:space:]]*protocol:[[:space:]]*efi' "$conf"; then
        echo "Tu entrada usa UKI (protocol:efi). Configurá kernel separado con respaldo así:" >&2
        echo "  sudo bash $HERE/setup-kernel-boot.sh" >&2
    fi
    exit 1
fi
