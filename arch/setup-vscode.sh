#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs Microsoft's Visual Studio Code build from the AUR, marketplace
# extensions, the Dark Legacy custom theme, and user settings on Arch Linux.
#
# Usage: ./setup-vscode.sh
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

if (( EUID == 0 )); then
    echo "ERROR: Run this script as a normal user; it invokes sudo when needed." >&2
    exit 1
fi

DARK_LEGACY_THEME="$HOME/.vscode/extensions/dark-legacy-theme/themes/dark-legacy.json"
if [[ ! -f "$DARK_LEGACY_THEME" ]]; then
    echo "ERROR: Dark Legacy theme not found at $DARK_LEGACY_THEME" >&2
    exit 1
fi

echo ">>> Setting up VS Code locally..."
sudo pacman -Syu --needed --noconfirm python

###############################################################################
# Install Microsoft's VS Code build
###############################################################################
if ! command -v code >/dev/null 2>&1; then
    echo ">>> Installing visual-studio-code-bin from the AUR..."
    sudo pacman -S --needed --noconfirm base-devel git

    if command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm visual-studio-code-bin
    elif command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm visual-studio-code-bin
    else
        AUR_BUILD_ROOT="$(mktemp -d)"
        cleanup_aur_build() {
            if [[ -n "${AUR_BUILD_ROOT:-}" && -d "$AUR_BUILD_ROOT" ]]; then
                rm -rf -- "$AUR_BUILD_ROOT"
            fi
        }
        trap cleanup_aur_build EXIT

        git clone https://aur.archlinux.org/visual-studio-code-bin.git \
            "$AUR_BUILD_ROOT/visual-studio-code-bin"
        (
            cd "$AUR_BUILD_ROOT/visual-studio-code-bin"
            makepkg -si --needed --noconfirm
        )

        cleanup_aur_build
        AUR_BUILD_ROOT=""
        trap - EXIT
    fi
else
    echo ">>> VS Code already installed — skipping."
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

VSCODE_THEMES=""
THEME_CANDIDATES=(
    /opt/visual-studio-code/resources/app/extensions/theme-defaults/themes
    /usr/lib/code/extensions/theme-defaults/themes
    /usr/share/code/resources/app/extensions/theme-defaults/themes
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
###############################################################################
echo ">>> Writing VS Code settings..."
mkdir -p "$HOME/.config/Code/User"
cat > "$HOME/.config/Code/User/settings.json" <<'SETTINGS_JSON_EOF'
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
