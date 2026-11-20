#!/usr/bin/env bash
# ceft-shell · instalador para un Arch recién instalado
#
#   gh auth login && gh repo clone ceftx/ceft-shell ~/ceft-shell && ~/ceft-shell/install.sh
#
# Opciones: --groups base,desktop  --all  -y
set -euo pipefail

REPO="${CEFT_REPO:-https://github.com/ceftx/ceft-shell.git}"
DEST="${CEFT_DIR:-$HOME/ceft-shell}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -x "$here/bin/ceft-shell" ]; then
    DEST="$here"
elif [ ! -d "$DEST/.git" ]; then
    sudo pacman -S --needed --noconfirm git
    git clone "$REPO" "$DEST"
fi

exec "$DEST/bin/ceft-shell" install "$@"
