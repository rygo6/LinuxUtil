#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-dev-tools.sh
#
# Runs the general Windows development-tool installers from Git Bash or
# MSYS2. Packages come from winget, which ships with Windows 11, so there is
# no package-manager bootstrap script like mac/setup-homebrew.sh.
#
# Not ported from the other folders:
#   - setup-ghostty.sh: Ghostty has no official Windows build.
#   - setup-fingerprint / setup-touchid.sh: Windows Hello is configured in
#     Settings > Accounts > Sign-in options, and there is no PAM to patch.
#   - setup-mesa*.sh: Windows GPU drivers come from the vendor.
#
# Usage: ./setup-dev-tools.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

if ! command -v winget >/dev/null 2>&1; then
    echo "ERROR: winget is not installed. Install App Installer from the Microsoft Store." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS=(
    setup-git.sh
    setup-clang.sh
    setup-vulkan.sh
    setup-vscode.sh
    setup-claude.sh
    setup-codex.sh
)

for script in "${SCRIPTS[@]}"; do
    echo ">>> Running $script..."
    "$SCRIPT_DIR/$script"
done

echo ">>> Windows dev tools setup complete."
echo "    Open a new shell to pick up the PATH and environment changes."
