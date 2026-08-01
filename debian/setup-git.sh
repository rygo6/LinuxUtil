#!/bin/bash
set -euo pipefail
###############################################################################
# setup-git.sh
#
# Installs the latest git + git-lfs (and shared prerequisites) on the local
# Ubuntu/Debian machine.
#
# Usage: ./setup-git.sh
###############################################################################

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
