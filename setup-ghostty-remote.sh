#!/bin/bash
set -euo pipefail
###############################################################################
# setup-ghostty-remote.sh
#
# Installs Ghostty and writes its config on a remote Ubuntu/Debian machine
# over SSH. (For a local install use setup-ghostty.sh.)
#
# Usage: ./setup-ghostty-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing Ghostty on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS — /etc/os-release not found." >&2
    exit 1
fi
. /etc/os-release
export DEBIAN_FRONTEND=noninteractive

# curl is needed by the Ubuntu installer.
sudo apt-get update
sudo apt-get install -y curl ca-certificates

echo ">>> Installing Ghostty..."
case "${ID:-}" in
    ubuntu)
        ghostty_installer="$(mktemp)"
        curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh -o "$ghostty_installer"
        /bin/bash "$ghostty_installer"
        rm -f "$ghostty_installer"
        ;;
    debian)
        curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
            | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
        echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" \
            | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list
        sudo apt-get update
        sudo apt-get install -y ghostty
        ;;
    *)
        echo "ERROR: Unsupported OS '${ID}'. Ubuntu and Debian only." >&2
        exit 1
        ;;
esac

echo ">>> Writing Ghostty config..."
mkdir -p "${HOME}/.config/ghostty"
cat <<'GHOSTTY_EOF' > "${HOME}/.config/ghostty/config"
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
GHOSTTY_EOF
echo "   Ghostty config written to ~/.config/ghostty/config"
REMOTE_EOF
