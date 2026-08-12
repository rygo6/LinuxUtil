#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-claude.sh
#
# Installs Claude Code with Anthropic's native installer and ensures
# ~/.local/bin is on PATH for future shells. macOS defaults to zsh, so the
# PATH line goes in ~/.zshrc rather than ~/.bashrc.
#
# Credentials can be copied with ../transfer-claude-credentials.sh.
#
# Usage: ./setup-claude.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

# curl and ca-certificates ship with macOS, so there is nothing to install
# before the Claude installer runs.
if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo ">>> Claude Code already installed — skipping."
fi

if ! grep -qs '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.zshrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo ">>> Claude Code install complete."
