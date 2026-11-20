#!/usr/bin/env bash
# Límite de espera al apagar/reiniciar. Lo corre: sudo bash system/shutdown/install.sh [usuario]
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
USER_NAME="${1:-${SUDO_USER:-$USER}}"

install_file() {
    local dst=$1 content=$2
    install -D -o root -g root -m 755 -d "$(dirname "$dst")"
    printf '%s\n' "$content" > "$dst"
    echo "Instalado $dst"
}
install_file /etc/systemd/system.conf.d/90-ceft-shell-timeouts.conf '[Manager]
DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
DefaultDeviceTimeoutSec=30s'
install_file /etc/systemd/user.conf.d/90-ceft-shell-timeouts.conf '[Manager]
DefaultTimeoutStartSec=60s
DefaultTimeoutStopSec=20s'

# Los servicios con un TimeoutStopSec propio no obedecen al predeterminado.
for svc in mariadb postgresql docker tailscaled; do
    if systemctl list-unit-files "$svc.service" --type=service >/dev/null 2>&1; then
        printf '%-16s ' "$svc"; systemctl show "$svc.service" -p TimeoutStopUSec --value
    fi
done
if systemctl list-unit-files mariadb.service --type=service >/dev/null 2>&1; then
    if [[ ${CEFT_FAST_DB:-0} == 1 ]]; then
        install_file /etc/systemd/system/mariadb.service.d/90-ceft-shell-timeout.conf '[Service]
# 2 minutos de margen para cerrar; si hay transacciones largas, mejor cerrarlas antes de apagar.
TimeoutStopSec=120s'
        echo "MariaDB: límite reducido de 15 min a 2 min. Si llega a agotarse, se terminará y la recuperación será al arrancar."
    else
        echo "MariaDB mantiene su margen de 15 min (más seguro si usas transacciones grandes)."
        echo "Para limitarlo a 2 min: CEFT_FAST_DB=1 sudo -E bash $0 $USER_NAME"
    fi
fi
systemctl daemon-reload
systemctl --user daemon-reload 2>/dev/null || true
echo "Listo. Vale desde el próximo apagado/reinicio."
