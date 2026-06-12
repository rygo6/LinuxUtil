#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Ghostty Install + Void Nord Config
# Supports: Ubuntu, Debian
###############################################################################

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS — /etc/os-release not found." >&2
    exit 1
fi

. /etc/os-release

case "${ID:-}" in
    ubuntu)
        echo ">>> Detected Ubuntu — installing Ghostty via mkasberg/ghostty-ubuntu..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
        ;;
    debian)
        echo ">>> Detected Debian — installing Ghostty via debian.griffo.io..."
        curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
            | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
        echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" \
            | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list
        sudo apt update
        sudo apt install -y ghostty
        ;;
    *)
        echo "ERROR: Unsupported OS '${ID}'. This script supports Ubuntu and Debian only." >&2
        exit 1
        ;;
esac

###############################################################################
# Ghostty config — Void Nord
###############################################################################
echo ">>> Writing Ghostty config..."
mkdir -p "${HOME}/.config/ghostty"
cat <<'EOF' > "${HOME}/.config/ghostty/config"
# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard
keybind = ctrl+shift+w=close_surface

# Splits
split-divider-color = #ff8c42

# Behavior
copy-on-select = false
EOF
echo "   Ghostty config written to ~/.config/ghostty/config"
