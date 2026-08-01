#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-claude.sh
#
# Installs Claude Code with Anthropic's native Linux installer and ensures
# ~/.local/bin is on PATH for future shells.
#
# Credentials can be copied with ../transfer-claude-credentials.sh.
#
# Usage: ./setup-claude.sh
###############################################################################

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: Cannot detect the operating system." >&2
    exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "arch" ]]; then
    echo "ERROR: This script supports Arch Linux only." >&2
    exit 1
fi

sudo pacman -Syu --needed --noconfirm curl ca-certificates

if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo ">>> Claude Code already installed — skipping."
fi

if ! grep -qs '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo ">>> Claude Code install complete."
