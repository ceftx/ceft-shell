#!/usr/bin/env bash
# ceft-shell · instalación de un comando en un Arch recién instalado:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/ceftx/ceft-shell/main/boot.sh)
#
# Opciones (se pasan al instalador): --groups base,desktop  --all  -y
set -euo pipefail

REPO="${CEFT_REPO:-https://github.com/ceftx/ceft-shell.git}"
DEST="${CEFT_DIR:-$HOME/ceft-shell}"

[ "$(id -u)" -ne 0 ] || { echo "No lo corras como root: usa tu usuario normal (pide sudo cuando haga falta)." >&2; exit 1; }
[ -r /etc/arch-release ] || { echo "ceft-shell es para Arch Linux." >&2; exit 1; }

command -v git >/dev/null || sudo pacman -S --needed --noconfirm git

if [ -d "$DEST/.git" ]; then
    git -C "$DEST" pull --ff-only
else
    git clone "$REPO" "$DEST"
fi

exec "$DEST/install.sh" "$@"
