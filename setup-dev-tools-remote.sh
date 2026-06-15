#!/bin/bash
set -euo pipefail

###############################################################################
# setup-dev-tools-remote.sh
#
# Provisions a remote Ubuntu/Debian machine over SSH by orchestrating the
# individual setup-*-remote.sh scripts (each also runnable standalone):
#
#   setup-git-credentials-remote.sh     SSH key + gitconfig
#   setup-git-remote.sh                 latest git + git-lfs (+ prerequisites)
#   setup-clang-remote.sh               clang, asan, lldb, clangd
#   setup-vulkan-remote.sh              LunarG Vulkan SDK
#   setup-vscode-remote.sh              VS Code
#   setup-ghostty-remote.sh             Ghostty + config
#   setup-claude-remote.sh              Claude Code
#   setup-claude-credentials-remote.sh  Claude credentials + onboarding state
#
# A single SSH master connection is opened here and shared with every
# sub-script (via SSH_CONTROL_PATH), so you authenticate only once.
#
# Usage: ./setup-dev-tools-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${1:-}" ]; then
    echo "Usage: $0 user@host"
    exit 1
fi
REMOTE="$1"

# Open one master connection (authenticate once) and share it with the
# sub-scripts. remote-lib.sh reuses SSH_CONTROL_PATH when it points at a live
# socket, so the children skip their own authentication.
export SSH_CONTROL_PATH="/tmp/ssh-setup-$$"
ssh -M -f -N -o ControlPath="$SSH_CONTROL_PATH" "$REMOTE"
trap 'ssh -O exit -o ControlPath="$SSH_CONTROL_PATH" "$REMOTE" 2>/dev/null' EXIT

"$SCRIPT_DIR/setup-git-credentials-remote.sh"    "$REMOTE"
"$SCRIPT_DIR/setup-git-remote.sh"                "$REMOTE"
"$SCRIPT_DIR/setup-clang-remote.sh"              "$REMOTE"
"$SCRIPT_DIR/setup-vulkan-remote.sh"             "$REMOTE"
"$SCRIPT_DIR/setup-vscode-remote.sh"             "$REMOTE"
"$SCRIPT_DIR/setup-ghostty-remote.sh"            "$REMOTE"
"$SCRIPT_DIR/setup-claude-remote.sh"             "$REMOTE"
"$SCRIPT_DIR/setup-claude-credentials-remote.sh" "$REMOTE"

echo "Done. Dev tools installed and credentials transferred to $REMOTE"
