#!/bin/bash
set -euo pipefail
###############################################################################
# setup-vscode-remote.sh
#
# Installs VS Code (Microsoft apt repo) on a remote Ubuntu/Debian machine
# over SSH.
#
# Usage: ./setup-vscode-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing VS Code on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

if ! command -v code >/dev/null 2>&1; then
    echo ">>> Installing VS Code..."
    sudo apt-get update
    sudo apt-get install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 \
        /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f /tmp/packages.microsoft.gpg
    sudo apt-get update
    sudo apt-get install -y code
else
    echo ">>> VS Code already installed — skipping."
fi
REMOTE_EOF
