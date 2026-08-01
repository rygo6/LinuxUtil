#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-git.sh
#
# Installs Git, Git LFS, and shared download prerequisites on Arch Linux.
#
# Usage: ./setup-git.sh
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

echo ">>> Installing Git, Git LFS, and shared prerequisites..."
sudo pacman -Syu --needed --noconfirm \
    git git-lfs curl ca-certificates xz

git lfs install
echo ">>> Git and Git LFS installed."
