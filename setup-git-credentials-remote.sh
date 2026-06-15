#!/bin/bash
set -euo pipefail
###############################################################################
# setup-git-credentials-remote.sh
#
# Copies git credentials (SSH key + gitconfig) from this machine to a remote.
#
# Usage: ./setup-git-credentials-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Copying git credentials (SSH key + gitconfig) to $REMOTE..."
$SSH "$REMOTE" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
$SCP ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub "$REMOTE":~/.ssh/
$SCP ~/.gitconfig "$REMOTE":~/.gitconfig
$SSH "$REMOTE" 'chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub'
echo "    git credentials copied."
