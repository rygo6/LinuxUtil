#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-codex.sh
#
# Installs Codex CLI on Windows and installs the shared auto-approve-folder
# profile. Run Codex with:
#
#   codex -p auto-approve-folder
#
# The profile skips approval prompts while retaining workspace-write sandboxing.
# The official PowerShell installer puts codex on the user PATH itself.
#
# Usage: ./setup-codex.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SOURCE="$SCRIPT_DIR/../codex/auto-approve-folder.config.toml"

# Codex reads its config from the Windows profile, which is not $HOME under
# MSYS2.
WIN_HOME="$(cygpath -u "$USERPROFILE")"
PROFILE_DEST="$WIN_HOME/.codex/auto-approve-folder.config.toml"

if ! command -v codex >/dev/null 2>&1; then
    echo ">>> Installing Codex CLI..."
    CODEX_NON_INTERACTIVE=1 powershell.exe -NoProfile -NonInteractive \
        -ExecutionPolicy Bypass -Command 'irm https://chatgpt.com/codex/install.ps1 | iex'
else
    echo ">>> Codex CLI already installed — skipping."
fi

mkdir -p "$WIN_HOME/.codex"
if [[ -f "$PROFILE_DEST" ]] && ! cmp -s "$PROFILE_SOURCE" "$PROFILE_DEST"; then
    backup_path="$(mktemp "$PROFILE_DEST.backup.XXXXXX")"
    cp -p "$PROFILE_DEST" "$backup_path"
    echo ">>> Backed up the existing profile to $backup_path"
fi
cp -- "$PROFILE_SOURCE" "$PROFILE_DEST"

echo ">>> Codex CLI setup complete."
echo "    Open a new shell, then start it with: codex -p auto-approve-folder"
