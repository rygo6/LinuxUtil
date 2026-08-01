#!/bin/bash
set -euo pipefail

###############################################################################
# setup-dev-tools.sh
#
# Sets up the general development tools on the local Ubuntu/Debian machine by
# running each installer below. Each installer is also runnable standalone.
#
# The fingerprint and Mesa installers are intentionally standalone because
# they are hardware/version-specific. Credential transfers are also separate.
#
# Usage: ./setup-dev-tools.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS=(
    setup-git.sh
    setup-clang.sh
    setup-vulkan.sh
    setup-vscode.sh
    setup-ghostty.sh
    setup-claude.sh
)

echo ">>> Authenticating sudo for local setup..."
sudo -v

for script in "${SCRIPTS[@]}"; do
    echo ">>> Running $script..."
    "$SCRIPT_DIR/$script"
done

echo ">>> Local dev tools setup complete."
