#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-clang.sh
#
# Installs the LLVM toolchain (clang, clangd, clang-tidy, clang-format, lld,
# lldb) on Windows, plus the MSVC Build Tools it links against.
#
# clang on Windows targets the MSVC ABI and uses the MSVC C/C++ runtime and
# the Windows SDK for headers and import libraries, so the Build Tools play the
# role the Xcode Command Line Tools play on macOS. An existing Visual Studio
# or Build Tools install with the C++ toolset is reused.
#
# Windows has no system clang to shadow, so LLVM's whole bin directory goes on
# the user PATH rather than symlinking individual tools.
#
# Usage: ./setup-clang.sh
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

WINGET_FLAGS=(
    --exact
    --source winget
    --accept-source-agreements
    --disable-interactivity
)

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

###############################################################################
# MSVC Build Tools
###############################################################################
VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
MSVC_PATH=""
if [[ -x "$VSWHERE" ]]; then
    MSVC_PATH="$("$VSWHERE" -latest -products '*' \
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
        -property installationPath | tr -d '\r')"
fi

if [[ -n "$MSVC_PATH" ]]; then
    echo ">>> MSVC C++ toolset already installed at $MSVC_PATH — skipping."
else
    echo ">>> Installing Visual Studio Build Tools with the C++ workload..."
    echo "    This is a multi-GB download and shows a UAC prompt."
    winget install --id Microsoft.VisualStudio.2022.BuildTools "${WINGET_FLAGS[@]}" \
        --accept-package-agreements \
        --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
fi

###############################################################################
# LLVM
###############################################################################
if winget list --id LLVM.LLVM "${WINGET_FLAGS[@]}" >/dev/null 2>&1; then
    echo ">>> LLVM already installed — checking for updates..."
    winget upgrade --id LLVM.LLVM "${WINGET_FLAGS[@]}" \
        --accept-package-agreements --silent || true
else
    echo ">>> Installing the LLVM toolchain..."
    winget install --id LLVM.LLVM "${WINGET_FLAGS[@]}" \
        --accept-package-agreements --silent
fi

LLVM_PREFIX="/c/Program Files/LLVM"
if [[ ! -x "$LLVM_PREFIX/bin/clang.exe" ]]; then
    echo "ERROR: clang.exe not found in $LLVM_PREFIX/bin after installation." >&2
    exit 1
fi

echo ">>> Putting LLVM on the user PATH..."
add_user_path "$LLVM_PREFIX/bin"

for tool in clangd clang-tidy clang-format clang-apply-replacements lld-link lldb; do
    if [[ ! -x "$LLVM_PREFIX/bin/$tool.exe" ]]; then
        echo "    WARNING: $tool not found in $LLVM_PREFIX/bin" >&2
    fi
done

echo ">>> Clang toolchain installed."
echo "    clang:  $(clang --version | head -n1)"
echo "    LLVM:   $(cygpath -w "$LLVM_PREFIX")"
echo "    Open a new shell to pick up the PATH change."
