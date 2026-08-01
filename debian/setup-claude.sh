#!/bin/bash
set -euo pipefail
###############################################################################
# setup-claude.sh
#
# Installs Claude Code on the local Ubuntu/Debian machine and ensures
# ~/.local/bin (Claude's install location) is on PATH for future shells.
#
# Credentials can be copied to another machine with
# ../transfer-claude-credentials.sh.
#
# Usage: ./setup-claude.sh
###############################################################################

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
