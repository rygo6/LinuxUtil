#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs Microsoft's Visual Studio Code build from Homebrew Cask,
# marketplace extensions, the Dark Legacy custom theme, and user settings on
# macOS.
#
# dark-legacy.json itself is not generated here — copy it over from another
# machine first, same as on Arch and Debian.
#
# Usage: ./setup-vscode.sh
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script supports macOS only." >&2
    exit 1
fi

if (( EUID == 0 )); then
    echo "ERROR: Run this script as a normal user; it invokes sudo when needed." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew is not installed. Run ./setup-homebrew.sh first." >&2
    exit 1
fi

DARK_LEGACY_THEME="$HOME/.vscode/extensions/dark-legacy-theme/themes/dark-legacy.json"
if [[ ! -f "$DARK_LEGACY_THEME" ]]; then
    echo "ERROR: Dark Legacy theme not found at $DARK_LEGACY_THEME" >&2
    exit 1
fi

echo ">>> Setting up VS Code locally..."

###############################################################################
# Install Microsoft's VS Code build
###############################################################################
if ! command -v code >/dev/null 2>&1; then
    echo ">>> Installing visual-studio-code from Homebrew Cask..."
    brew install --cask visual-studio-code
else
    echo ">>> VS Code already installed — skipping."
fi

if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: The 'code' CLI is not on PATH after installation." >&2
    echo "       Ensure $(brew --prefix)/bin precedes /usr/bin in PATH." >&2
    exit 1
fi

###############################################################################
# Marketplace extensions
###############################################################################
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
for extension in "${EXTENSIONS[@]}"; do
    code --install-extension "$extension" --force
done

###############################################################################
# Dark Legacy custom theme
###############################################################################
echo ">>> Installing Dark Legacy theme..."
THEME_DIR="$HOME/.vscode/extensions/dark-legacy-theme/themes"
mkdir -p "$THEME_DIR"

cat > "$HOME/.vscode/extensions/dark-legacy-theme/package.json" <<'PACKAGE_JSON_EOF'
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
PACKAGE_JSON_EOF

# Copy the include chain from the VS Code built-in themes. On macOS these live
# inside the app bundle rather than under /usr/share.
VSCODE_THEMES=""
THEME_CANDIDATES=(
    "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions/theme-defaults/themes"
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/extensions/theme-defaults/themes"
)
for candidate in "${THEME_CANDIDATES[@]}"; do
    if [[ -d "$candidate" ]]; then
        VSCODE_THEMES="$candidate"
        break
    fi
done

if [[ -z "$VSCODE_THEMES" ]]; then
    echo "ERROR: Cannot find VS Code's built-in theme directory." >&2
    exit 1
fi

for theme_file in dark_modern.json dark_plus.json dark_vs.json; do
    cp "$VSCODE_THEMES/$theme_file" "$THEME_DIR/$theme_file"
done

python3 - <<'PYTHON_EOF'
import json
import os

path = os.path.expanduser("~/.vscode/extensions/extensions.json")
try:
    with open(path) as source:
        extensions = json.load(source)
except (FileNotFoundError, json.JSONDecodeError):
    extensions = []

entry_id = "local.dark-legacy-theme"
if not any(
    extension.get("identifier", {}).get("id") == entry_id
    for extension in extensions
):
    home = os.path.expanduser("~")
    extensions.insert(0, {
        "identifier": {"id": entry_id},
        "version": "1.0.0",
        "location": {
            "$mid": 1,
            "path": f"{home}/.vscode/extensions/dark-legacy-theme",
            "scheme": "file",
        },
        "relativeLocation": "dark-legacy-theme",
        "metadata": {
            "installedTimestamp": 0,
            "source": "vsix",
            "isPreReleaseVersion": False,
            "hasPreReleaseVersion": False,
        },
    })
    with open(path, "w") as destination:
        json.dump(extensions, destination)
    print("Registered dark-legacy-theme in extensions.json")
else:
    print("dark-legacy-theme already registered — skipping.")
PYTHON_EOF

###############################################################################
# User settings
#
# macOS stores VS Code's user settings under Application Support rather than
# ~/.config/Code.
###############################################################################
echo ">>> Writing VS Code settings..."
SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$SETTINGS_DIR"
cat > "$SETTINGS_DIR/settings.json" <<'SETTINGS_JSON_EOF'
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
SETTINGS_JSON_EOF

echo ">>> VS Code setup complete."
