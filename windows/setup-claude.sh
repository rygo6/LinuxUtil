#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-claude.sh
#
# Installs Claude Code with Anthropic's native Windows installer and ensures
# %USERPROFILE%\.local\bin is on the user PATH for future shells. Claude Code
# on Windows runs its shell commands through Git Bash, so setup-git.sh should
# have been run first.
#
# The PATH entry goes in the Windows user environment rather than ~/.bashrc so
# that PowerShell, cmd, and VS Code see it as well as Git Bash. MSYS2 shells
# only inherit it when MSYS2_PATH_TYPE=inherit.
#
# Credentials can be copied with ./transfer-claude-credentials.sh.
#
# Usage: ./setup-claude.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

# Claude Code reads its config from the Windows profile, which is not $HOME
# under MSYS2.
WIN_HOME="$(cygpath -u "$USERPROFILE")"

# Prepends a directory to the persistent user PATH. The raw registry value is
# edited so existing %VAR% entries are not expanded away, then a dummy
# variable is cleared through .NET to broadcast the change to new shells.
add_user_path() {
    local dir="$1"
    export PATH="$dir:$PATH"
    ADD_USER_PATH="$(cygpath -w "$dir")" powershell.exe -NoProfile -NonInteractive -Command '
        $dir = $env:ADD_USER_PATH
        $key = Get-Item -Path "HKCU:\Environment"
        $path = $key.GetValue("Path", "", "DoNotExpandEnvironmentNames")
        $entries = $path -split ";" | Where-Object { $_ }
        if ($entries -contains $dir) { exit 0 }
        Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Type ExpandString `
            -Value ((@($dir) + $entries) -join ";")
        [Environment]::SetEnvironmentVariable("LINUXUTIL_PATH_BROADCAST", $null, "User")
        Write-Host "    Added $dir to the user PATH."
    '
}

if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$WIN_HOME/.local/bin/claude.exe" ]]; then
    echo ">>> Installing Claude Code..."
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \
        'irm https://claude.ai/install.ps1 | iex'
else
    echo ">>> Claude Code already installed — skipping."
fi

echo ">>> Ensuring ~/.local/bin is on the user PATH..."
add_user_path "$WIN_HOME/.local/bin"

echo ">>> Claude Code install complete."
