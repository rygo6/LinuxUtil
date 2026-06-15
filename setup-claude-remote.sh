#!/bin/bash
set -euo pipefail
###############################################################################
# setup-claude-remote.sh
#
# Installs Claude Code on a remote Ubuntu/Debian machine over SSH, and ensures
# ~/.local/bin (Claude's install location) is on PATH for future shells.
#
# Credentials are handled separately by setup-claude-credentials-remote.sh.
#
# Usage: ./setup-claude-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing Claude Code on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# curl is needed by the Claude installer.
sudo apt-get update
sudo apt-get install -y curl ca-certificates

if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo ">>> Claude Code already installed — skipping."
fi

# Ensure ~/.local/bin (Claude's install location) is on PATH for future shells
if ! grep -qs '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
echo ">>> Claude Code install complete."
REMOTE_EOF
