#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vulkan.sh
#
# Installs the LunarG Vulkan SDK on Windows, mirroring ../mac/setup-vulkan.sh,
# ../arch/setup-vulkan.sh, and ../debian/setup-vulkan.sh.
#
# Windows needs far less than the other platforms: the Vulkan loader
# (vulkan-1.dll) and the ICD ship with the GPU vendor's driver, and the SDK
# installer itself sets VULKAN_SDK and puts the SDK's Bin directory on the
# system PATH. There is nothing to copy into a system prefix and no Mesa.
#
# The installer is LunarG's own Qt Installer Framework app, run headless. It
# installs into C:\VulkanSDK\<version> and needs administrator rights, so it is
# launched elevated and shows a UAC prompt.
#
# Usage: ./setup-vulkan.sh
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        exit 1
        ;;
esac

if [[ "${PROCESSOR_ARCHITECTURE:-}" != "AMD64" ]]; then
    echo "ERROR: This script supports x64 Windows only." >&2
    exit 1
fi

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

# SDK build dependencies. The Windows SDK ships prebuilt binaries plus GLM and
# the other headers as installer components, so only the build tools that
# projects drive it with are needed here.
echo ">>> Installing Vulkan SDK build dependencies..."
for package in Kitware.CMake Ninja-build.Ninja; do
    if winget list --id "$package" "${WINGET_FLAGS[@]}" >/dev/null 2>&1; then
        echo "    $package already installed — skipping."
    else
        winget install --id "$package" "${WINGET_FLAGS[@]}" \
            --accept-package-agreements --silent
    fi
done

###############################################################################
# Download and install the SDK
###############################################################################
echo ">>> Installing LunarG Vulkan SDK..."
VULKAN_SDK_VERSION="$(curl -fsSL https://vulkan.lunarg.com/sdk/latest/windows.txt | tr -d '\r\n')"
echo "    Latest SDK version: ${VULKAN_SDK_VERSION}"

VULKAN_SDK_ROOT="/c/VulkanSDK/${VULKAN_SDK_VERSION}"

if [[ -d "$VULKAN_SDK_ROOT" ]]; then
    echo "    Vulkan SDK ${VULKAN_SDK_VERSION} already installed — skipping download."
else
    STAGING_DIR="$(mktemp -d)"
    cleanup_staging() {
        if [[ -n "${STAGING_DIR:-}" && -d "$STAGING_DIR" ]]; then
            rm -rf -- "$STAGING_DIR"
        fi
    }
    trap cleanup_staging EXIT

    echo "    Downloading vulkan_sdk.exe (~300 MB)..."
    curl -fSL --retry 3 \
        "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/windows/vulkan_sdk.exe" \
        -o "$STAGING_DIR/vulkan_sdk.exe"

    # The installer's manifest requires elevation, which a plain exec from bash
    # cannot request, so PowerShell launches it with the RunAs verb. The
    # default component set matches the core SDK the Linux tarball provides.
    echo "    Running the SDK installer into $(cygpath -w "$VULKAN_SDK_ROOT")..."
    VK_INSTALLER="$(cygpath -w "$STAGING_DIR/vulkan_sdk.exe")" \
    VK_ROOT="$(cygpath -w "$VULKAN_SDK_ROOT")" \
        powershell.exe -NoProfile -NonInteractive -Command '
            $p = Start-Process -FilePath $env:VK_INSTALLER -Verb RunAs -Wait -PassThru `
                -ArgumentList "--root", $env:VK_ROOT, "--accept-licenses", `
                    "--default-answer", "--confirm-command", "install"
            exit $p.ExitCode
        '

    cleanup_staging
    STAGING_DIR=""
    trap - EXIT
fi

VULKAN_SDK_BIN="${VULKAN_SDK_ROOT}/Bin"
if [[ ! -d "$VULKAN_SDK_BIN" ]]; then
    echo "ERROR: Expected SDK directory $VULKAN_SDK_BIN does not exist." >&2
    exit 1
fi

###############################################################################
# Verify
#
# This shell predates the installer's environment changes, so the SDK binary
# is called by its full path.
###############################################################################
if "${VULKAN_SDK_BIN}/vulkaninfoSDK.exe" --summary >/dev/null 2>&1; then
    "${VULKAN_SDK_BIN}/vulkaninfoSDK.exe" --summary
else
    echo "WARNING: The SDK is installed, but vulkaninfo found no working driver." >&2
    echo "         Make sure the GPU vendor's driver is installed and up to date." >&2
fi

echo ">>> Vulkan SDK setup complete."
echo "    Open a new shell to pick up VULKAN_SDK and the SDK PATH entry."
