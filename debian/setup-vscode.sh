#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs VS Code (Microsoft apt repo), marketplace extensions, and user
# settings on the local Ubuntu/Debian machine.
# Safe to rerun: verified items are skipped and missing items are repaired.
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
SETUP_FAILED=0

########################################
# Install VS Code
########################################
echo ">>> Installing or updating VS Code..."
sudo apt-get update -q
sudo apt-get install -y wget gpg

MICROSOFT_KEY_TMP="$(mktemp)"
VSCODE_SOURCE_TMP="$(mktemp)"
cleanup_repository_temp() {
    rm -f -- "$MICROSOFT_KEY_TMP"
    rm -f -- "$VSCODE_SOURCE_TMP"
}
trap cleanup_repository_temp EXIT

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor --yes --output "$MICROSOFT_KEY_TMP"
MICROSOFT_KEY="/usr/share/keyrings/microsoft.gpg"
if [[ -f "$MICROSOFT_KEY" ]] && cmp -s "$MICROSOFT_KEY_TMP" "$MICROSOFT_KEY"; then
    echo ">>> Verified Microsoft repository signing key."
else
    sudo install -D -o root -g root -m 644 \
        "$MICROSOFT_KEY_TMP" "$MICROSOFT_KEY"
    echo ">>> Updated Microsoft repository signing key."
fi

cat > "$VSCODE_SOURCE_TMP" <<'VSCODE_SOURCES_EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
VSCODE_SOURCES_EOF

VSCODE_SOURCE="/etc/apt/sources.list.d/vscode.sources"
if [[ -f "$VSCODE_SOURCE" ]] && cmp -s "$VSCODE_SOURCE_TMP" "$VSCODE_SOURCE"; then
    echo ">>> Verified Microsoft VS Code apt source."
else
    sudo install -D -o root -g root -m 644 \
        "$VSCODE_SOURCE_TMP" "$VSCODE_SOURCE"
    echo ">>> Updated Microsoft VS Code apt source."
fi

# Remove the legacy one-line source created by older versions of this script.
LEGACY_VSCODE_SOURCE="/etc/apt/sources.list.d/vscode.list"
if [[ -f "$LEGACY_VSCODE_SOURCE" ]] && \
    grep -q 'packages.microsoft.com/repos/code' "$LEGACY_VSCODE_SOURCE"; then
    sudo rm -f -- "$LEGACY_VSCODE_SOURCE"
    echo ">>> Removed legacy duplicate VS Code apt source."
fi

cleanup_repository_temp
trap - EXIT

sudo apt-get update -q
sudo apt-get install -y code

if ! dpkg-query -W -f='${Status}\n' code 2>/dev/null | \
    grep -Fqx 'install ok installed'; then
    echo "ERROR: Debian package verification failed: code" >&2
    exit 1
fi

if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: The 'code' CLI is not on PATH after installation." >&2
    exit 1
fi
CODE_VERSION="$(code --version)"
CODE_VERSION="${CODE_VERSION%%$'\n'*}"
echo ">>> Verified VS Code $CODE_VERSION."

########################################
# Marketplace extensions
########################################
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

########################################
# User settings
# Dark 2026 is bundled with VS Code, so no separate theme file is required.
########################################
echo ">>> Verifying VS Code settings..."
SETTINGS_DIR="$HOME/.config/Code/User"
mkdir -p "$SETTINGS_DIR"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
SETTINGS_TMP="$(mktemp)"
cleanup_settings() {
    rm -f -- "$SETTINGS_TMP"
}
trap cleanup_settings EXIT

cat > "$SETTINGS_TMP" <<'SETTINGSJSON'
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
