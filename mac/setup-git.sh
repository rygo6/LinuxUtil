#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-git.sh
#
# Installs Git, Git LFS, and shared download prerequisites on macOS.
#
# macOS ships an old Git behind the Xcode Command Line Tools shim, so this
# installs Homebrew's Git and makes sure Homebrew's bin directory precedes
# /usr/bin on PATH.
#
# Usage: ./setup-git.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew is not installed. Run ./setup-homebrew.sh first." >&2
    exit 1
fi

# curl, ca-certificates, and xz all ship with macOS, so only git and git-lfs
# have to be installed. Homebrew's xz is still worth having for `tar -J`
# parity with the Linux scripts.
echo ">>> Installing Git, Git LFS, and shared prerequisites..."
brew install git git-lfs xz

git lfs install
echo ">>> Git and Git LFS installed."
git --version
