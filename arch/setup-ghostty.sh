#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-ghostty.sh
#
# Installs Ghostty from the official Arch repository and writes its config.
#
# Usage: ./setup-ghostty.sh
###############################################################################

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: Cannot detect the operating system." >&2
    exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "arch" ]]; then
    echo "ERROR: This script supports Arch Linux only." >&2
    exit 1
fi

echo ">>> Installing Ghostty..."
sudo pacman -Syu --needed --noconfirm ghostty

echo ">>> Writing Ghostty config..."
mkdir -p "$HOME/.config/ghostty"
cat > "$HOME/.config/ghostty/config" <<'GHOSTTY_EOF'
# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard
keybind = ctrl+shift+w=close_surface
keybind = ctrl+shift+equal=equalize_splits

# Splits
split-divider-color = #ff8c42

# Behavior
copy-on-select = false
GHOSTTY_EOF

echo ">>> Ghostty setup complete."
