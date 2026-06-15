#!/bin/bash
set -euo pipefail
###############################################################################
# setup-git-remote.sh
#
# Installs the latest git + git-lfs (and shared prerequisites) on a remote
# Ubuntu/Debian machine over SSH.
#
# Usage: ./setup-git-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing latest git + git-lfs on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS — /etc/os-release not found." >&2
    exit 1
fi
. /etc/os-release
export DEBIAN_FRONTEND=noninteractive

# Prerequisites shared by the curl-based installers (Vulkan, Ghostty, Claude).
echo ">>> Installing prerequisites (curl, ca-certificates, xz-utils)..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates xz-utils

echo ">>> Installing latest git + git-lfs..."
case "${ID:-}" in
    ubuntu)
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:git-core/ppa
        ;;
    debian) ;;
    *)
        echo "ERROR: Unsupported OS '${ID}'. Ubuntu and Debian only." >&2
        exit 1
        ;;
esac
sudo apt-get update
sudo apt-get install -y git git-lfs
# Initialize git-lfs for this user
git lfs install
echo ">>> git + git-lfs installed."
REMOTE_EOF
