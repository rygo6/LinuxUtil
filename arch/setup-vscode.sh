#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs Microsoft's Visual Studio Code build from the AUR, marketplace
# extensions, and user settings on Arch Linux.
# Safe to rerun: verified items are skipped and missing items are repaired.
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

echo ">>> Setting up VS Code locally..."
SETUP_FAILED=0

###############################################################################
# Install or update Microsoft's VS Code build
###############################################################################
echo ">>> Installing or updating visual-studio-code-bin from the AUR..."
sudo pacman -Syu --needed --noconfirm base-devel git

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

if ! pacman -Q visual-studio-code-bin >/dev/null 2>&1; then
    echo "ERROR: Arch package verification failed: visual-studio-code-bin" >&2
    exit 1
fi

if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: The 'code' CLI is not on PATH after installation." >&2
    exit 1
fi
CODE_VERSION="$(code --version)"
CODE_VERSION="${CODE_VERSION%%$'\n'*}"
echo ">>> Verified VS Code $CODE_VERSION."

###############################################################################
# Marketplace extensions
###############################################################################
echo ">>> Verifying extensions..."
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
INSTALLED_EXTENSIONS="$(code --list-extensions | tr '[:upper:]' '[:lower:]')"
for extension in "${EXTENSIONS[@]}"; do
    if grep -Fqx -- "$extension" <<<"$INSTALLED_EXTENSIONS"; then
        echo "    verified: $extension"
    elif code --install-extension "$extension"; then
        echo "    installed: $extension"
        INSTALLED_EXTENSIONS="${INSTALLED_EXTENSIONS}"$'\n'"${extension}"
    else
        echo "ERROR: Failed to install extension: $extension" >&2
        SETUP_FAILED=1
    fi
done

INSTALLED_EXTENSIONS="$(code --list-extensions | tr '[:upper:]' '[:lower:]')"
for extension in "${EXTENSIONS[@]}"; do
    if ! grep -Fqx -- "$extension" <<<"$INSTALLED_EXTENSIONS"; then
        echo "ERROR: Required extension is still missing: $extension" >&2
        SETUP_FAILED=1
    fi
done

###############################################################################
# User settings
# Dark 2026 is bundled with VS Code, so no separate theme file is required.
###############################################################################
echo ">>> Verifying VS Code settings..."
SETTINGS_DIR="$HOME/.config/Code/User"
mkdir -p "$SETTINGS_DIR"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
SETTINGS_TMP="$(mktemp)"
cleanup_settings() {
    rm -f -- "$SETTINGS_TMP"
}
trap cleanup_settings EXIT

cat > "$SETTINGS_TMP" <<'SETTINGS_JSON_EOF'
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
SETTINGS_JSON_EOF

if [[ -f "$SETTINGS_FILE" ]] && cmp -s "$SETTINGS_TMP" "$SETTINGS_FILE"; then
    echo "    verified: $SETTINGS_FILE"
else
    install -m 644 "$SETTINGS_TMP" "$SETTINGS_FILE"
    echo "    updated: $SETTINGS_FILE"
fi

if ! cmp -s "$SETTINGS_TMP" "$SETTINGS_FILE"; then
    echo "ERROR: VS Code settings verification failed: $SETTINGS_FILE" >&2
    SETUP_FAILED=1
fi

cleanup_settings
trap - EXIT

if (( SETUP_FAILED != 0 )); then
    echo "ERROR: VS Code setup finished with verification failures." >&2
    exit 1
fi

echo ">>> VS Code setup complete and verified."
