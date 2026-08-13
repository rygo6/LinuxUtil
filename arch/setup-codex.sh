#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-codex.sh
#
# Installs Codex CLI on Arch Linux and installs the shared
# auto-approve-folder profile. Run Codex with:
#
#   codex -p auto-approve-folder
#
# The profile skips approval prompts while retaining workspace-write sandboxing.
# Usage: ./setup-codex.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="$SCRIPT_DIR/../codex/auto-approve-folder.config.toml"
PROFILE_DEST="$HOME/.codex/auto-approve-folder.config.toml"

sudo pacman -Syu --needed --noconfirm curl ca-certificates

if ! command -v codex >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/codex" ]]; then
    echo ">>> Installing Codex CLI..."
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
else
    echo ">>> Codex CLI already installed — skipping."
fi

if ! grep -qs '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

mkdir -p "$HOME/.codex"
if [[ -f "$PROFILE_DEST" ]] && ! cmp -s "$PROFILE_SOURCE" "$PROFILE_DEST"; then
    backup_path="$(mktemp "$PROFILE_DEST.backup.XXXXXX")"
    cp -p "$PROFILE_DEST" "$backup_path"
    echo ">>> Backed up the existing profile to $backup_path"
fi
install -m 600 "$PROFILE_SOURCE" "$PROFILE_DEST"

echo ">>> Codex CLI setup complete."
echo "    Start it with: codex -p auto-approve-folder"
