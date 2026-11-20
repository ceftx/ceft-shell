#!/usr/bin/env bash
# Instala el killswitch VPN del sistema (lo llama `ceft-shell system`).
#   sudo bash install.sh <usuario>
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
USER_NAME="${1:-${SUDO_USER:?pasá el usuario}}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN=/usr/local/bin/vpn-killswitch

install -o root -g root -m 755 "$HERE/vpn-killswitch" "$BIN"
[[ -f /etc/vpn-killswitch.conf ]] || install -o root -g root -m 644 "$HERE/killswitch.conf.example" /etc/vpn-killswitch.conf

SUDOERS=/etc/sudoers.d/vpn-killswitch
echo "$USER_NAME ALL=(root) NOPASSWD: $BIN on, $BIN off, $BIN status" > "$SUDOERS.tmp"
chmod 440 "$SUDOERS.tmp"
visudo -cf "$SUDOERS.tmp" >/dev/null && mv "$SUDOERS.tmp" "$SUDOERS"

cat > /etc/systemd/system/vpn-killswitch-docker.service <<UNIT
[Unit]
Description=Reaplicar killswitch VPN para contenedores Docker
After=docker.service
PartOf=docker.service

[Service]
Type=oneshot
ExecStart=$BIN sync
RemainAfterExit=yes

[Install]
WantedBy=docker.service
UNIT
systemctl daemon-reload
systemctl enable vpn-killswitch-docker.service >/dev/null 2>&1

# Si estaba activo, re-aplicar reglas con la versión nueva
if [[ "$($BIN state)" == on ]]; then "$BIN" on >/dev/null; fi
echo "Killswitch instalado · estado: $($BIN state)"
