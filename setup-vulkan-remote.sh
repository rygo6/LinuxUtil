#!/bin/bash
set -euo pipefail
###############################################################################
# setup-vulkan-remote.sh
#
# Installs the LunarG Vulkan SDK (tarball method) on a remote Ubuntu/Debian
# machine over SSH. The SDK env is sourced via ~/.bashrc and the headers,
# loader, and layers are copied into /usr/local.
#
# Usage: ./setup-vulkan-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

echo ">>> Installing LunarG Vulkan SDK on $REMOTE..."
remote_run <<'REMOTE_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# curl is needed to query/download the SDK.
sudo apt-get update
sudo apt-get install -y curl ca-certificates xz-utils

# --- LunarG Vulkan SDK (tarball method) ---
# The apt repo only covers jammy/noble and stopped updating after May 2025, so
# we use the version-independent tarball from sdk.lunarg.com.
echo ">>> Installing LunarG Vulkan SDK..."
VULKAN_SDK_VERSION="$(curl -fsSL https://vulkan.lunarg.com/sdk/latest/linux.txt)"
echo "    Latest SDK version: ${VULKAN_SDK_VERSION}"

# SDK build/runtime dependencies (from LunarG getting_started)
sudo apt-get install -y \
    cmake ninja-build pkg-config bison \
    libglm-dev libxcb-dri3-0 libxcb-present0 libpciaccess0 \
    libpng-dev libxcb-keysyms1-dev libxcb-dri3-dev libx11-dev \
    libx11-xcb-dev libxcb-randr0-dev libxcb-ewmh-dev \
    libwayland-dev libxrandr-dev wayland-protocols \
    libxml2-dev liblz4-dev libzstd-dev python3-jsonschema

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

sudo ldconfig
echo "    Vulkan SDK files copied to /usr/local"
REMOTE_EOF
