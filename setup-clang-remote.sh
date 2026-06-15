#!/bin/bash
set -euo pipefail
###############################################################################
# setup-clang-remote.sh
#
# Installs the clang toolchain (clang, asan via clang/llvm, lldb, clangd, and
# friends) on a remote Ubuntu/Debian machine over SSH.
#
# Usage: ./setup-clang-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing clang toolchain on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo ">>> Installing clang toolchain (clang, asan, lldb, clangd)..."
sudo apt-get update
sudo apt-get install -y \
    clang clangd lldb llvm lld \
    clang-tools clang-tidy clang-format \
    libc++-dev libc++abi-dev
echo ">>> clang toolchain installed."
REMOTE_EOF
