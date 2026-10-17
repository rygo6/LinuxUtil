#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs Microsoft's Visual Studio Code build from winget (user scope),
# marketplace extensions, and user settings on Windows.
# Safe to rerun: verified items are skipped and missing items are repaired.
#
# Usage: ./setup-vscode.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

if ! command -v winget >/dev/null 2>&1; then
    echo "ERROR: winget is not installed. Install App Installer from the Microsoft Store." >&2
    exit 1
fi

echo ">>> Setting up VS Code locally..."
SETUP_FAILED=0

WINGET_FLAGS=(
    --exact
    --source winget
    --accept-source-agreements
    --disable-interactivity
)

###############################################################################
# Install or update Microsoft's VS Code build
###############################################################################
install_vscode_package() {
    if winget list --id Microsoft.VisualStudioCode "${WINGET_FLAGS[@]}" >/dev/null 2>&1; then
        # winget upgrade exits non-zero when there is nothing newer, so an
        # up-to-date install is detected separately and treated as success.
        # `list --upgrade-available` exits 0 either way; only its output says
        # whether an upgrade exists.
        if winget list --id Microsoft.VisualStudioCode "${WINGET_FLAGS[@]}" \
            --upgrade-available 2>/dev/null | grep -Fqi 'Microsoft.VisualStudioCode'; then
            echo ">>> Updating Microsoft.VisualStudioCode from winget..."
            winget upgrade --id Microsoft.VisualStudioCode "${WINGET_FLAGS[@]}" \
                --accept-package-agreements --silent
        else
            echo ">>> Verified winget package: Microsoft.VisualStudioCode."
        fi
    else
        echo ">>> Installing Microsoft.VisualStudioCode from winget..."
        winget install --id Microsoft.VisualStudioCode "${WINGET_FLAGS[@]}" \
            --scope user --accept-package-agreements \
            --override "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath"
    fi
}

# The VS Code CDN intermittently fails TLS handshakes, so retry the whole
# install on failure.
for attempt in 1 2 3; do
    if install_vscode_package; then
        break
    fi
    if (( attempt == 3 )); then
        echo "ERROR: Failed to install Microsoft.VisualStudioCode after $attempt attempts." >&2
        exit 1
    fi
    echo ">>> Install attempt $attempt failed; retrying in 15 seconds..."
    sleep 15
done

if ! winget list --id Microsoft.VisualStudioCode "${WINGET_FLAGS[@]}" >/dev/null 2>&1; then
    echo "ERROR: winget package verification failed: Microsoft.VisualStudioCode" >&2
    exit 1
fi

# This shell predates the installer's PATH change, so also look in the
# default user and machine install locations.
if ! command -v code >/dev/null 2>&1; then
    for code_bin in "$(cygpath -u "$LOCALAPPDATA")/Programs/Microsoft VS Code/bin" \
        "/c/Program Files/Microsoft VS Code/bin"; do
        if [[ -x "$code_bin/code" ]]; then
            export PATH="$code_bin:$PATH"
            break
        fi
    done
fi

if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: The 'code' CLI is not on PATH after installation." >&2
    exit 1
fi
CODE_VERSION="$(code --version | tr -d '\r')"
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
INSTALLED_EXTENSIONS="$(code --list-extensions | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
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

INSTALLED_EXTENSIONS="$(code --list-extensions | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
for extension in "${EXTENSIONS[@]}"; do
    if ! grep -Fqx -- "$extension" <<<"$INSTALLED_EXTENSIONS"; then
        echo "ERROR: Required extension is still missing: $extension" >&2
        SETUP_FAILED=1
    fi
done

###############################################################################
# User settings
#
# Dark 2026 is bundled with VS Code, so no separate theme file is required.
#
# Windows stores VS Code's user settings under %APPDATA%\Code\User. It is
# resolved from APPDATA because MSYS2's $HOME is not the Windows profile.
###############################################################################
echo ">>> Verifying VS Code settings..."
SETTINGS_DIR="$(cygpath -u "$APPDATA")/Code/User"
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
    cp -- "$SETTINGS_TMP" "$SETTINGS_FILE"
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
