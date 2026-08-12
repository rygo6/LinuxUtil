#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vulkan.sh
#
# Installs the LunarG Vulkan SDK on macOS, mirroring ../arch/setup-vulkan.sh
# and ../debian/setup-vulkan.sh. The SDK env is sourced via ~/.zshrc and the
# headers, loader, layers, and the MoltenVK ICD are copied into /usr/local.
#
# macOS has no native Vulkan driver — the SDK ships MoltenVK, a Vulkan-to-Metal
# translation layer, which takes the place of the Mesa drivers the Linux
# folders install separately. There is therefore no mac/setup-mesa*.sh.
#
# Homebrew publishes no Vulkan SDK cask, so this uses LunarG's own installer
# app in headless mode.
#
# Usage: ./setup-vulkan.sh
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

# SDK build dependencies (macOS equivalents of the LunarG getting_started
# package lists). curl, xz, and the X/Wayland stack are either preinstalled or
# irrelevant on macOS, so this list is much shorter than the Linux ones.
# Homebrew has no jsonschema formula, but the macOS SDK ships prebuilt
# binaries and never runs the Python code generators, so it is not needed.
echo ">>> Installing Vulkan SDK build dependencies..."
brew install cmake ninja pkgconf bison glm

###############################################################################
# Download and install the SDK
###############################################################################
echo ">>> Installing LunarG Vulkan SDK..."
VULKAN_SDK_VERSION="$(curl -fsSL https://vulkan.lunarg.com/sdk/latest/mac.txt)"
echo "    Latest SDK version: ${VULKAN_SDK_VERSION}"

VULKAN_SDK_ROOT="${HOME}/VulkanSDK/${VULKAN_SDK_VERSION}"

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

    echo "    Downloading vulkan_sdk.zip (~340 MB)..."
    curl -fsSL "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/mac/vulkan_sdk.zip" \
        -o "$STAGING_DIR/vulkan_sdk.zip"
    unzip -q "$STAGING_DIR/vulkan_sdk.zip" -d "$STAGING_DIR"

    INSTALLER_APP="$(find "$STAGING_DIR" -maxdepth 1 -name 'vulkansdk-macOS-*.app' -print -quit)"
    if [[ -z "$INSTALLER_APP" ]]; then
        echo "ERROR: Installer app not found in the downloaded archive." >&2
        exit 1
    fi

    # Strip any quarantine attribute so the installer runs without a Gatekeeper
    # prompt in this non-interactive context.
    xattr -dr com.apple.quarantine "$INSTALLER_APP" 2>/dev/null || true

    INSTALLER_BIN="$INSTALLER_APP/Contents/MacOS/$(basename "$INSTALLER_APP" .app)"
    if [[ ! -x "$INSTALLER_BIN" ]]; then
        echo "ERROR: Installer binary not found at $INSTALLER_BIN" >&2
        exit 1
    fi

    # Qt Installer Framework headless install. The default component set
    # (com.lunarg.vulkan.core) is what the Linux tarball provides; the system
    # global install is done explicitly below instead of via the installer's
    # com.lunarg.vulkan.usr component, which needs a GUI privilege prompt.
    echo "    Running the SDK installer into $VULKAN_SDK_ROOT..."
    "$INSTALLER_BIN" \
        --root "$VULKAN_SDK_ROOT" \
        --accept-licenses \
        --default-answer \
        --confirm-command \
        install

    cleanup_staging
    STAGING_DIR=""
    trap - EXIT
fi

###############################################################################
# Source the SDK environment in future shells
###############################################################################
# Replace any prior Vulkan SDK line. BSD sed needs an explicit (empty) backup
# suffix for -i, unlike GNU sed.
if [[ -f "$HOME/.zshrc" ]]; then
    sed -i '' '\#VulkanSDK/.*/setup-env.sh#d' "$HOME/.zshrc" 2>/dev/null || true
fi
echo "source \"\$HOME/VulkanSDK/${VULKAN_SDK_VERSION}/setup-env.sh\"" >> "$HOME/.zshrc"
echo "    Vulkan SDK env (setup-env.sh) added to ~/.zshrc"

###############################################################################
# Copy SDK headers, loader, layers, and the MoltenVK ICD into /usr/local
#
# Files are located with find because the layout shifts between SDK versions.
# The layer and ICD manifests reference their libraries with paths relative to
# the manifest (../../../lib/...), which resolve correctly under /usr/local
# once the dylibs are copied to /usr/local/lib.
###############################################################################
echo ">>> Copying Vulkan SDK files into /usr/local..."
VULKAN_SDK_DIR="${VULKAN_SDK_ROOT}/macOS"
if [[ ! -d "$VULKAN_SDK_DIR" ]]; then
    echo "ERROR: Expected SDK directory $VULKAN_SDK_DIR does not exist." >&2
    exit 1
fi

sudo mkdir -p /usr/local/include /usr/local/lib

# Headers
sudo cp -R "${VULKAN_SDK_DIR}/include/vulkan/" /usr/local/include/vulkan/

# Loader (libvulkan.dylib / libvulkan.1.dylib) — wherever it lives in this
# SDK version.
loader_path="$(find "${VULKAN_SDK_DIR}" -name 'libvulkan.*dylib' -print -quit)"
if [[ -z "$loader_path" ]]; then
    echo "ERROR: libvulkan dylib not found under $VULKAN_SDK_DIR." >&2
    exit 1
fi
sudo cp -P "$(dirname "$loader_path")"/libvulkan.*dylib /usr/local/lib/

# MoltenVK — the Metal-backed Vulkan driver
moltenvk_lib="$(find "${VULKAN_SDK_DIR}" -name 'libMoltenVK.dylib' -print -quit)"
if [[ -n "$moltenvk_lib" ]]; then
    sudo cp "$moltenvk_lib" /usr/local/lib/
else
    echo "WARNING: libMoltenVK.dylib not found in the SDK." >&2
fi

moltenvk_json="$(find "${VULKAN_SDK_DIR}" -path '*/icd.d/MoltenVK_icd.json' -print -quit)"
if [[ -n "$moltenvk_json" ]]; then
    sudo mkdir -p /usr/local/share/vulkan/icd.d
    sudo cp "$moltenvk_json" /usr/local/share/vulkan/icd.d/
else
    echo "WARNING: MoltenVK_icd.json not found in the SDK." >&2
fi

# Layer libraries
layer_lib_path="$(find "${VULKAN_SDK_DIR}" -name 'libVkLayer_*.dylib' -print -quit)"
if [[ -z "$layer_lib_path" ]]; then
    echo "ERROR: Validation layer dylibs not found under $VULKAN_SDK_DIR." >&2
    exit 1
fi
sudo cp "$(dirname "$layer_lib_path")"/libVkLayer_*.dylib /usr/local/lib/

# Layer manifests
layer_json_path="$(find "${VULKAN_SDK_DIR}" -path '*/explicit_layer.d/VkLayer_*.json' -print -quit)"
if [[ -z "$layer_json_path" ]]; then
    echo "ERROR: Layer manifests not found under $VULKAN_SDK_DIR." >&2
    exit 1
fi
sudo mkdir -p /usr/local/share/vulkan/explicit_layer.d
sudo cp "$(dirname "$layer_json_path")"/VkLayer_*.json /usr/local/share/vulkan/explicit_layer.d/

# macOS has no ldconfig; /usr/local/lib is already on dyld's default search
# path, so nothing further is needed here.
echo "    Vulkan SDK files copied to /usr/local"

###############################################################################
# Verify
###############################################################################
if "${VULKAN_SDK_DIR}/bin/vulkaninfo" --summary >/dev/null 2>&1; then
    "${VULKAN_SDK_DIR}/bin/vulkaninfo" --summary
else
    echo "WARNING: The SDK is installed, but vulkaninfo found no working driver." >&2
    echo "         Open a new shell so setup-env.sh is sourced and retry." >&2
fi

echo ">>> Vulkan SDK setup complete."
