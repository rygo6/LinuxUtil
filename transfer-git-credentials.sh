#!/bin/bash
set -euo pipefail
###############################################################################
# transfer-git-credentials.sh
#
# Transfers git credentials (SSH key + gitconfig) from this machine to another.
#
# Usage: ./transfer-git-credentials.sh user@host
###############################################################################

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 user@host" >&2
    exit 1
fi

TARGET="$1"
SOCKET="/tmp/ssh-transfer-$$"

ssh -M -f -N -o ControlPath="$SOCKET" "$TARGET"

cleanup() {
    ssh -O exit -o ControlPath="$SOCKET" "$TARGET" 2>/dev/null || true
}
trap cleanup EXIT

SSH=(ssh -o "ControlPath=$SOCKET")
SCP=(scp -o "ControlPath=$SOCKET")

echo ">>> Transferring git credentials (SSH key + gitconfig) to $TARGET..."
"${SSH[@]}" "$TARGET" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
"${SCP[@]}" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub" \
    "$TARGET":~/.ssh/
"${SCP[@]}" "$HOME/.gitconfig" "$TARGET":~/.gitconfig
"${SSH[@]}" "$TARGET" \
    'chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub'
echo "    Git credentials transferred."
