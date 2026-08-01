#!/bin/bash
set -euo pipefail
###############################################################################
# setup-clang.sh
#
# Installs the clang toolchain (clang, asan via clang/llvm, lldb, clangd, and
# friends) on the local Ubuntu/Debian machine.
#
# Usage: ./setup-clang.sh
###############################################################################

export DEBIAN_FRONTEND=noninteractive

echo ">>> Installing clang toolchain (clang, asan, lldb, clangd)..."
sudo apt-get update
sudo apt-get install -y \
    clang clangd lldb llvm lld \
    clang-tools clang-tidy clang-format \
    libc++-dev libc++abi-dev
echo ">>> clang toolchain installed."
