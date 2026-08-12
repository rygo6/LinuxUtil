#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-clang.sh
#
# Installs the LLVM toolchain (clangd, clang-tidy, clang-format, lld, LLVM
# runtimes, libc++) on macOS.
#
# Apple's Command Line Tools already provide clang, lldb, and libc++, but they
# omit clangd, clang-tidy, and clang-format entirely. Homebrew's llvm is
# keg-only precisely so it does not shadow Apple clang — replacing the system
# compiler breaks linking against the macOS SDK. So instead of putting all of
# Homebrew's LLVM on PATH, this symlinks only the tools Apple does not ship
# into ~/.local/bin.
#
# Usage: ./setup-clang.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew is not installed. Run ./setup-homebrew.sh first." >&2
    exit 1
fi

echo ">>> Installing the LLVM toolchain..."
brew install llvm lld

LLVM_PREFIX="$(brew --prefix llvm)"

###############################################################################
# Expose the tools Apple's clang does not ship, without shadowing it
###############################################################################
echo ">>> Linking LLVM tools into ~/.local/bin..."
mkdir -p "$HOME/.local/bin"

LLVM_TOOLS=(
    clangd
    clang-tidy
    clang-format
    clang-apply-replacements
    run-clang-tidy
)
for tool in "${LLVM_TOOLS[@]}"; do
    if [[ -x "$LLVM_PREFIX/bin/$tool" ]]; then
        ln -sfn "$LLVM_PREFIX/bin/$tool" "$HOME/.local/bin/$tool"
        echo "    $tool -> $LLVM_PREFIX/bin/$tool"
    else
        echo "    WARNING: $tool not found in $LLVM_PREFIX/bin" >&2
    fi
done

if ! grep -qs '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.zshrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo ">>> Clang toolchain installed."
echo "    System compiler:  $(command -v clang) ($(clang --version | head -n1))"
echo "    Homebrew LLVM:    $LLVM_PREFIX"
echo "    Build against Homebrew's clang explicitly with:"
echo "        CC=$LLVM_PREFIX/bin/clang CXX=$LLVM_PREFIX/bin/clang++"
