#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-homebrew.sh
#
# Installs the Xcode Command Line Tools and Homebrew on macOS, and puts brew
# on PATH for future shells. This is the macOS equivalent of having pacman or
# apt already present, so every other script in this folder assumes it has
# been run first.
#
# Usage: ./setup-homebrew.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if (( EUID == 0 )); then
    echo "ERROR: Run this script as a normal user; it invokes sudo when needed." >&2
    exit 1
fi

###############################################################################
# Xcode Command Line Tools
#
# Provides the system clang, lldb, git, and the SDK headers everything else
# links against.
###############################################################################
if xcode-select -p >/dev/null 2>&1; then
    echo ">>> Xcode Command Line Tools already installed — skipping."
else
    echo ">>> Installing Xcode Command Line Tools..."
    # `xcode-select --install` opens a GUI dialog and returns immediately, so
    # poll until the tools actually land.
    xcode-select --install >/dev/null 2>&1 || true
    echo "    Accept the installer dialog; waiting for it to finish..."
    until xcode-select -p >/dev/null 2>&1; do
        /bin/sleep 10
    done
    echo "    Xcode Command Line Tools installed."
fi

# A full Xcode.app install leaves the license unaccepted, which makes brew and
# every xc* tool fail until it is agreed to. With only the Command Line Tools
# selected, xcodebuild errors for an unrelated reason and this is skipped.
if /usr/bin/xcodebuild -version 2>&1 | grep -qi 'license'; then
    echo ">>> Accepting the Xcode license..."
    sudo xcodebuild -license accept
fi

###############################################################################
# Homebrew
###############################################################################
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

if command -v brew >/dev/null 2>&1; then
    echo ">>> Homebrew already installed — skipping."
elif [[ -x "$BREW_PREFIX/bin/brew" ]]; then
    echo ">>> Homebrew already installed at $BREW_PREFIX — skipping."
else
    echo ">>> Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# Put brew on PATH for future shells.
if ! grep -qs 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    echo ">>> Adding brew shellenv to ~/.zprofile..."
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
fi

echo ">>> Updating Homebrew..."
brew update

echo ">>> Homebrew setup complete."
