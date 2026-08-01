#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vulkan.sh
#
# Installs Arch's Vulkan development group, validation layers, tools, shader
# compilers, and common native build dependencies. Files stay package-managed
# under /usr; no LunarG tarball or ~/.bashrc environment hook is needed.
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

echo ">>> Installing the Vulkan development toolchain..."
sudo pacman -Syu --needed --noconfirm \
    vulkan-devel shaderc glslang directx-shader-compiler \
    cmake ninja pkgconf bison glm \
    libpciaccess libpng libx11 libxcb libxrandr xcb-util-keysyms \
    wayland wayland-protocols libxml2 lz4 zstd python-jsonschema

echo ">>> Vulkan development toolchain installed."
if vulkaninfo --summary >/dev/null 2>&1; then
    vulkaninfo --summary
else
    echo "WARNING: Vulkan tools are installed, but vulkaninfo found no working GPU driver." >&2
    echo "         Install the driver for your GPU or run setup-mesa26_1.sh." >&2
fi
