#!/bin/bash
set -euo pipefail

###############################################################################
# setup-dev-tools-remote.sh
#
# Provisions a remote Ubuntu/Debian machine over SSH by orchestrating every
# setup-*-remote.sh script in this directory (each also runnable standalone).
#
# A single SSH master connection is opened and shared with every sub-script
# (via SSH_CONTROL_PATH), so you authenticate only once over SSH.
#
# sudo is authenticated once at the start; a temporary NOPASSWD sudoers entry
# is written for the duration of the run so sub-scripts never re-prompt.
# The entry is removed on exit (even on failure).
#
# Usage: ./setup-dev-tools-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"

if [ -z "${1:-}" ]; then
    echo "Usage: $0 user@host"
    exit 1
fi
REMOTE="$1"

# Open master connection manually so we own the trap.
SOCKET="/tmp/ssh-setup-$$"
ssh -M -f -N -o ControlPath="$SOCKET" "$REMOTE"
SSH="ssh -o ControlPath=$SOCKET"
SCP="scp -o ControlPath=$SOCKET"

cleanup() {
    $SSH "$REMOTE" "sudo rm -f /etc/sudoers.d/99-setup-temp" 2>/dev/null || true
    ssh -O exit -o ControlPath="$SOCKET" "$REMOTE" 2>/dev/null || true
}
trap cleanup EXIT

# Export so sub-scripts reuse this socket instead of opening their own.
export SSH_CONTROL_PATH="$SOCKET"

# Authenticate sudo once; write a temp NOPASSWD entry so no sub-script re-prompts.
echo ">>> Authenticating sudo on $REMOTE (you will be prompted once)..."
remote_run <<'EOF'
sudo -v
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-setup-temp > /dev/null
sudo chmod 440 /etc/sudoers.d/99-setup-temp
EOF

for script in "$SCRIPT_DIR"/setup-*-remote.sh; do
    [ "$script" = "${BASH_SOURCE[0]}" ] && continue
    "$script" "$REMOTE"
done

echo "Done. Dev tools installed and credentials transferred to $REMOTE"
