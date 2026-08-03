#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vulkan.sh
#
# Installs the LunarG Vulkan SDK (tarball method) on the local Arch machine,
# mirroring ../debian/setup-vulkan.sh. The SDK env is sourced via ~/.bashrc and
# the headers, loader, and layers are copied into /usr/local.
#
# The SDK ships newer validation layers than Arch's vulkan-devel group, so this
# deliberately does not install vulkan-devel — only the build dependencies the
# SDK needs.
#
# Usage: ./setup-vulkan.sh
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

# --- LunarG Vulkan SDK (tarball method) ---
# The version-independent tarball from sdk.lunarg.com is the only supported
# route on Arch; LunarG publishes no Arch packages.
echo ">>> Installing LunarG Vulkan SDK..."

# SDK build/runtime dependencies (Arch equivalents of LunarG getting_started)
sudo pacman -Syu --needed --noconfirm \
    curl ca-certificates xz \
    cmake ninja pkgconf bison glm \
    libpciaccess libpng libx11 libxcb libxrandr \
    xcb-util-keysyms xcb-util-wm \
    wayland wayland-protocols libxml2 lz4 zstd python-jsonschema

VULKAN_SDK_VERSION="$(curl -fsSL https://vulkan.lunarg.com/sdk/latest/linux.txt)"
echo "    Latest SDK version: ${VULKAN_SDK_VERSION}"

mkdir -p "${HOME}/vulkan"
if [ ! -d "${HOME}/vulkan/${VULKAN_SDK_VERSION}" ]; then
    sdk_tarball="$(mktemp --suffix=.tar.xz)"
    curl -fsSL "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkan_sdk.tar.xz" \
        -o "$sdk_tarball"
    tar -xf "$sdk_tarball" -C "${HOME}/vulkan"
    rm -f "$sdk_tarball"
else
    echo "    Vulkan SDK ${VULKAN_SDK_VERSION} already extracted — skipping download."
fi

# Source the SDK environment in future shells (replace any prior Vulkan SDK line)
sed -i '\#vulkan/.*/setup-env.sh#d' "$HOME/.bashrc" 2>/dev/null || true
echo "source \"\$HOME/vulkan/${VULKAN_SDK_VERSION}/setup-env.sh\"" >> "$HOME/.bashrc"
echo "    Vulkan SDK env (setup-env.sh) added to ~/.bashrc"

# Copy SDK headers, loader, and layers into system directories (/usr/local).
# Locate files with find since the layout shifts between SDK versions
# (e.g. the loader moved from lib/ to lib/VulkanLoader/lib/ after 1.4.341).
echo ">>> Copying Vulkan SDK files into /usr/local..."
VULKAN_SDK_DIR="${HOME}/vulkan/${VULKAN_SDK_VERSION}/x86_64"

# Headers
sudo mkdir -p /usr/local/include /usr/local/lib
sudo cp -r "${VULKAN_SDK_DIR}/include/vulkan/" /usr/local/include/

# Loader (libvulkan.so*) — wherever it lives in this SDK version
loader_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -name 'libvulkan.so*' | head -n1)")"
sudo cp -P "${loader_dir}"/libvulkan.so* /usr/local/lib/

# Layer libraries
layer_lib_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -name 'libVkLayer_*.so' | head -n1)")"
sudo cp "${layer_lib_dir}"/libVkLayer_*.so /usr/local/lib/

# Layer manifests
layer_json_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -path '*/explicit_layer.d/VkLayer_*.json' | head -n1)")"
sudo mkdir -p /usr/local/share/vulkan/explicit_layer.d
sudo cp "${layer_json_dir}"/VkLayer_*.json /usr/local/share/vulkan/explicit_layer.d/

# Unlike Debian, Arch's ld.so does not search /usr/local/lib by default.
if [[ ! -f /etc/ld.so.conf.d/usr-local-lib.conf ]]; then
    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/usr-local-lib.conf >/dev/null
    echo "    Added /usr/local/lib to the loader search path."
fi

sudo ldconfig
echo "    Vulkan SDK files copied to /usr/local"

if "${VULKAN_SDK_DIR}/bin/vulkaninfo" --summary >/dev/null 2>&1; then
    "${VULKAN_SDK_DIR}/bin/vulkaninfo" --summary
else
    echo "WARNING: The SDK is installed, but vulkaninfo found no working GPU driver." >&2
    echo "         Install the driver for your GPU or run setup-mesa26_1.sh." >&2
fi
