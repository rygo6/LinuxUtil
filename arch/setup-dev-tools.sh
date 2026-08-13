#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-dev-tools.sh
#
# Runs the general Arch Linux development-tool installers. Fingerprint and
# Mesa setup remain standalone because they are hardware-specific.
#
# Usage: ./setup-dev-tools.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS=(
    setup-git.sh
    setup-clang.sh
    setup-vulkan.sh
    setup-vscode.sh
    setup-ghostty.sh
    setup-claude.sh
    setup-codex.sh
)

echo ">>> Authenticating sudo for local setup..."
sudo -v

for script in "${SCRIPTS[@]}"; do
    echo ">>> Running $script..."
    "$SCRIPT_DIR/$script"
done

echo ">>> Arch Linux dev tools setup complete."
