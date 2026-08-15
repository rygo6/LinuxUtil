#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vscode.sh
#
# Installs Microsoft's Visual Studio Code build from Homebrew Cask,
# marketplace extensions, and user settings on macOS.
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

echo ">>> Setting up VS Code locally..."

###############################################################################
# Install Microsoft's VS Code build
###############################################################################
if ! brew list --cask visual-studio-code >/dev/null 2>&1; then
    echo ">>> Installing visual-studio-code from Homebrew Cask..."
    brew install --cask visual-studio-code
elif [[ -n "$(brew outdated --cask --quiet visual-studio-code)" ]]; then
    echo ">>> Updating visual-studio-code from Homebrew Cask..."
    brew upgrade --cask visual-studio-code
else
    echo ">>> VS Code is current — skipping."
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
for extension in "${EXTENSIONS[@]}"; do
    code --install-extension "$extension" --force
done

###############################################################################
# User settings
#
# Dark 2026 is bundled with VS Code, so no separate theme file is required.
#
# macOS stores VS Code's user settings under Application Support rather than
# ~/.config/Code.
###############################################################################
echo ">>> Writing VS Code settings..."
SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$SETTINGS_DIR"
cat > "$SETTINGS_DIR/settings.json" <<'SETTINGS_JSON_EOF'
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

echo ">>> VS Code setup complete."
