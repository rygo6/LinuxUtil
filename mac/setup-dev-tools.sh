#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-dev-tools.sh
#
# Runs the general macOS development-tool installers. Touch ID setup remains
# standalone because it is hardware-specific, matching how the Linux folders
# keep fingerprint and Mesa separate.
#
# There is no Mesa installer here: macOS has no open-source GPU driver stack,
# and setup-vulkan.sh installs MoltenVK, which fills that role.
#
# Usage: ./setup-dev-tools.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if (( EUID == 0 )); then
    echo "ERROR: Run this script as a normal user; it invokes sudo when needed." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS=(
    setup-homebrew.sh
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

    # setup-homebrew.sh may have installed brew for the first time; pull it
    # onto PATH so the remaining scripts can find it.
    if [[ "$script" == "setup-homebrew.sh" ]] && ! command -v brew >/dev/null 2>&1; then
        for brew_prefix in /opt/homebrew /usr/local; do
            if [[ -x "$brew_prefix/bin/brew" ]]; then
                eval "$("$brew_prefix/bin/brew" shellenv)"
                break
            fi
        done
    fi
done

echo ">>> macOS dev tools setup complete."
