#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-git.sh
#
# Installs Git for Windows (which bundles Git LFS) from winget on Windows.
#
# Runs from Git Bash or MSYS2. Git Bash ships its own git, but installing the
# winget package keeps it updated and gives native Windows tools (VS Code,
# Claude Code, Codex) a git.exe on the Windows PATH. curl, xz, and tar all
# ship with Git Bash and MSYS2, so nothing else is needed.
#
# Usage: ./setup-git.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

if ! command -v winget >/dev/null 2>&1; then
    echo "ERROR: winget is not installed. Install App Installer from the Microsoft Store." >&2
    exit 1
fi

WINGET_FLAGS=(
    --exact
    --source winget
    --accept-source-agreements
    --disable-interactivity
)

# An existing install is left alone rather than upgraded: when this runs from
# Git Bash, the installer would be replacing the very bash.exe running it.
if winget list --id Git.Git "${WINGET_FLAGS[@]}" >/dev/null 2>&1; then
    echo ">>> Git for Windows already installed — skipping."
    echo "    Update it from a non-Git-Bash shell with: winget upgrade Git.Git"
else
    echo ">>> Installing Git for Windows..."
    winget install --id Git.Git "${WINGET_FLAGS[@]}" \
        --accept-package-agreements --silent
fi

# Pick up the freshly installed git when this shell did not have one yet.
if ! command -v git >/dev/null 2>&1; then
    export PATH="/c/Program Files/Git/cmd:$PATH"
fi

git lfs install
echo ">>> Git and Git LFS installed."
git --version
