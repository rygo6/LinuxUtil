#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-clang.sh
#
# Installs Clang, clangd, clang-tidy, clang-format, LLDB, LLD, LLVM runtimes,
# and libc++ on Arch Linux.
#
# Usage: ./setup-clang.sh
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

echo ">>> Installing the Clang toolchain..."
sudo pacman -Syu --needed --noconfirm \
    clang llvm lld lldb compiler-rt libc++ libc++abi

echo ">>> Clang toolchain installed."
