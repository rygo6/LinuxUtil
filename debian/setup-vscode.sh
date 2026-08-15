#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs VS Code (Microsoft apt repo), marketplace extensions, and user
# settings on the local Ubuntu/Debian machine.
#
# Usage: ./setup-vscode.sh
###############################################################################

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: Cannot detect the operating system." >&2
    exit 1
fi

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*) ;;
    *)
        echo "ERROR: This script supports Debian and Ubuntu-based Linux only." >&2
        exit 1
        ;;
esac

if (( EUID == 0 )); then
    echo "ERROR: Run this script as a normal user; it invokes sudo when needed." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo ">>> Setting up VS Code locally..."

########################################
# Install VS Code
########################################
echo ">>> Installing or updating VS Code..."
sudo apt-get update -q
sudo apt-get install -y wget gpg

MICROSOFT_KEY_TMP="$(mktemp)"
cleanup_key() {
    rm -f -- "$MICROSOFT_KEY_TMP"
}
trap cleanup_key EXIT

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor --yes --output "$MICROSOFT_KEY_TMP"
sudo install -D -o root -g root -m 644 \
    "$MICROSOFT_KEY_TMP" /usr/share/keyrings/microsoft.gpg

sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'VSCODE_SOURCES_EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
VSCODE_SOURCES_EOF

# Remove the legacy one-line source created by older versions of this script.
LEGACY_VSCODE_SOURCE="/etc/apt/sources.list.d/vscode.list"
if [[ -f "$LEGACY_VSCODE_SOURCE" ]] && \
    grep -q 'packages.microsoft.com/repos/code' "$LEGACY_VSCODE_SOURCE"; then
    sudo rm -f -- "$LEGACY_VSCODE_SOURCE"
fi

cleanup_key
trap - EXIT

sudo apt-get update -q
sudo apt-get install -y code

if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: The 'code' CLI is not on PATH after installation." >&2
    exit 1
fi

########################################
# Marketplace extensions
########################################
echo ">>> Installing extensions..."
EXTENSIONS=(
    anthropic.claude-code
    donjayamanne.githistory
    llvm-vs-code-extensions.lldb-dap
    llvm-vs-code-extensions.vscode-clangd
    ms-python.debugpy
    ms-python.python
    ms-python.vscode-pylance
    ms-python.vscode-python-envs
    ms-vscode.cmake-tools
    ms-vscode.cpp-devtools
    ms-vscode.cpptools
    ms-vscode.cpptools-extension-pack
    ms-vscode.cpptools-themes
    ms-vscode.makefile-tools
    ms-vscode.remote-explorer
    pomber.git-file-history
    shader-slang.slang-language-extension
    swiftlang.swift-vscode
    vadimcn.vscode-lldb
    waderyan.gitblame
    yo1dog.cursor-align
)
for ext in "${EXTENSIONS[@]}"; do
    code --install-extension "$ext" --force
done

########################################
# User settings
# Dark 2026 is bundled with VS Code, so no separate theme file is required.
########################################
echo ">>> Writing VS Code settings..."
mkdir -p "$HOME/.config/Code/User"
cat > "$HOME/.config/Code/User/settings.json" << 'SETTINGSJSON'
{
    "workbench.colorTheme": "Dark 2026",
    "claudeCode.preferredLocation": "panel",
    "gitlens.ai.model": "vscode",
    "gitlens.ai.vscode.model": "copilot:gpt-4.1",
    "github.copilot.enable": {
        "*": false,
        "plaintext": false,
        "markdown": false,
        "scminput": false
    },
    "diffEditor.ignoreTrimWhitespace": true,
    "git.openRepositoryInParentFolders": "always",
    "C_Cpp.intelliSenseEngine": "disabled",
    "editor.parameterHints.enabled": false,
    "editor.inlayHints.enabled": "off",
    "makefile.configureOnOpen": true,
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
    }
}
SETTINGSJSON

echo ">>> VS Code setup complete."
