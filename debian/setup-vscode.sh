#!/bin/bash
set -euo pipefail
###############################################################################
# setup-vscode.sh
#
# Installs VS Code (Microsoft apt repo), marketplace extensions, the Dark
# Legacy custom theme, and user settings on the local Ubuntu/Debian machine.
#
# Usage: ./setup-vscode.sh
###############################################################################

export DEBIAN_FRONTEND=noninteractive

DARK_LEGACY_THEME="$HOME/.vscode/extensions/dark-legacy-theme/themes/dark-legacy.json"
if [[ ! -f "$DARK_LEGACY_THEME" ]]; then
    echo "ERROR: Dark Legacy theme not found at $DARK_LEGACY_THEME" >&2
    exit 1
fi

echo ">>> Setting up VS Code locally..."

########################################
# Install VS Code
########################################
if ! command -v code >/dev/null 2>&1; then
    echo ">>> Installing VS Code..."
    sudo apt-get update -q
    sudo apt-get install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 \
        /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f /tmp/packages.microsoft.gpg
    sudo apt-get update -q
    sudo apt-get install -y code
else
    echo ">>> VS Code already installed — skipping."
fi

########################################
# Marketplace extensions
########################################
echo ">>> Installing extensions..."
EXTENSIONS=(
    llvm-vs-code-extensions.vscode-clangd
    monokai.theme-monokai-pro-vscode
    ms-vscode.cmake-tools
    ms-vscode.cpp-devtools
    ms-vscode.cpptools
    ms-vscode.cpptools-themes
    ms-vscode.makefile-tools
    openai.chatgpt
    vadimcn.vscode-lldb
    yo1dog.cursor-align
)
for ext in "${EXTENSIONS[@]}"; do
    code --install-extension "$ext" --force
done

########################################
# Dark Legacy custom theme
########################################
echo ">>> Installing Dark Legacy theme..."
THEME_DIR="$HOME/.vscode/extensions/dark-legacy-theme/themes"
mkdir -p "$THEME_DIR"

cat > "$HOME/.vscode/extensions/dark-legacy-theme/package.json" << 'PKGJSON'
{
  "name": "dark-legacy-theme",
  "displayName": "Dark Legacy Theme",
  "version": "1.0.0",
  "publisher": "local",
  "engines": { "vscode": "*" },
  "contributes": {
    "themes": [
      {
        "id": "Dark Legacy",
        "label": "Dark Legacy",
        "uiTheme": "vs-dark",
        "path": "./themes/dark-legacy.json"
      }
    ]
  }
}
PKGJSON

# Copy the include chain from the VS Code built-in themes
VSCODE_THEMES="/usr/share/code/resources/app/extensions/theme-defaults/themes"
for f in dark_modern.json dark_plus.json dark_vs.json; do
    cp "$VSCODE_THEMES/$f" "$THEME_DIR/$f"
done

# Register the theme in the extensions manifest
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.vscode/extensions/extensions.json")
try:
    with open(path) as f:
        exts = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    exts = []
entry_id = "local.dark-legacy-theme"
if not any(e["identifier"]["id"] == entry_id for e in exts):
    home = os.path.expanduser("~")
    exts.insert(0, {
        "identifier": {"id": entry_id},
        "version": "1.0.0",
        "location": {
            "$mid": 1,
            "path": f"{home}/.vscode/extensions/dark-legacy-theme",
            "scheme": "file"
        },
        "relativeLocation": "dark-legacy-theme",
        "metadata": {"installedTimestamp": 0, "source": "vsix",
                     "isPreReleaseVersion": False, "hasPreReleaseVersion": False}
    })
    with open(path, "w") as f:
        json.dump(exts, f)
    print("Registered dark-legacy-theme in extensions.json")
else:
    print("dark-legacy-theme already registered — skipping.")
PYEOF

########################################
# User settings
########################################
echo ">>> Writing VS Code settings..."
mkdir -p "$HOME/.config/Code/User"
cat > "$HOME/.config/Code/User/settings.json" << 'SETTINGSJSON'
{
    "makefile.configureOnOpen": true,
    "C_Cpp.intelliSenseEngine": "disabled",
    "editor.semanticTokenColorCustomizations": {
        "[Dark 2026]": {
            "rules": {
                "variable": "#D4D4D4",
                "variable.functionScope": "#D4D4D4",
                "variable.local": "#D4D4D4",
                "property": "#D4D4D4",
                "property.classScope": "#D4D4D4",
                "parameter": "#FFA657"
            }
        }
    },
    "editor.tokenColorCustomizations": {
        "[Dark 2026]": {
            "textMateRules": [
                {
                    "scope": [
                        "variable",
                        "variable.other",
                        "variable.other.readwrite",
                        "variable.other.member",
                        "variable.other.property",
                        "variable.other.object"
                    ],
                    "settings": { "foreground": "#D4D4D4" }
                },
                {
                    "scope": [
                        "variable.parameter",
                        "variable.parameter.function"
                    ],
                    "settings": { "foreground": "#FFA657" }
                },
                {
                    "scope": [
                        "source.cpp meta.initialization variable.other",
                        "variable.other.property.cpp",
                        "meta.body.struct variable.other"
                    ],
                    "settings": { "foreground": "#D4D4D4" }
                }
            ]
        }
    },
    "chat.disableAIFeatures": true
}
SETTINGSJSON

echo ">>> VS Code setup complete."
