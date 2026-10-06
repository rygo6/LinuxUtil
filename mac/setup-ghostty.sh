#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-ghostty.sh
#
# Installs Ghostty from Homebrew Cask and writes its config.
#
# The config is kept byte-identical to arch/ and debian/ so terminal behavior
# matches across machines. Note that on macOS the ctrl+c / ctrl+v bindings sit
# alongside the native cmd+c / cmd+v ones rather than replacing them; the
# `performable:` prefix means ctrl+c still sends SIGINT when nothing is
# selected.
#
# Usage: ./setup-ghostty.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew is not installed. Run ./setup-homebrew.sh first." >&2
    exit 1
fi

if [[ -d "/Applications/Ghostty.app" ]]; then
    echo ">>> Ghostty already installed — skipping."
else
    echo ">>> Installing Ghostty..."
    brew install --cask ghostty
fi

# Ghostty on macOS reads ~/.config/ghostty/config as well as its
# Application Support path, so the Linux location works unchanged.
echo ">>> Writing Ghostty config..."
mkdir -p "$HOME/.config/ghostty"
cat > "$HOME/.config/ghostty/config" <<'GHOSTTY_EOF'
# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard
keybind = ctrl+shift+w=close_surface
keybind = ctrl+shift+equal=equalize_splits

# Splits
split-divider-color = #ff8c42

# Behavior
copy-on-select = false
GHOSTTY_EOF

echo ">>> Ghostty setup complete."
echo "    Config written to ~/.config/ghostty/config"
