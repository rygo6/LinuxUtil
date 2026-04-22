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
# Void Nord — Nord aesthetic shifted from polar blue to Void green
#
# Forest Night (backgrounds)
#   #2b332d  #353f37  #404c42  #4c594e
# Snow Moss (foregrounds)
#   #cdd7cf  #dae3dc  #e8f0ea
# Void Green (accent greens — replaces Nord's blues)
#   #295340  #406551  #478061  #abc2ab
# Aurora (harmonized warm colors)
#   red #bf616a  orange #c88a6a  yellow #dbc07a  green #abc2ab  purple #9a7a8e

background = #18181b
background-opacity = 0.90
foreground = #d4ddd6
cursor-color = #478061
selection-background = #478061
selection-foreground = #e8f0ea

# Palette — 16 ANSI colors
# Black
palette = 0=#2b332d
palette = 8=#4c594e
# Red
palette = 1=#bf616a
palette = 9=#d08770
# Green
palette = 2=#478061
palette = 10=#abc2ab
# Yellow
palette = 3=#dbc07a
palette = 11=#ebcb8b
# Blue (teal, no pure blue)
palette = 4=#5a7a6e
palette = 12=#7a9a8e
# Magenta
palette = 5=#9a7a8e
palette = 13=#b48ead
# Cyan
palette = 6=#7a9e86
palette = 14=#8abaa0
# White
palette = 7=#d2d2d6
palette = 15=#ececf0

# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard

# Behavior
copy-on-select = false
EOF
echo "   Ghostty config written to ~/.config/ghostty/config"
