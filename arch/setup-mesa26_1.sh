#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-mesa26_1.sh
#
# Installs Mesa 26.1 or newer plus the common open-source Vulkan drivers on
# Arch Linux. Arch is rolling-release, so this installs the repository's
# current Mesa version rather than pinning an old package build.
#
# Usage: ./setup-mesa26_1.sh
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

MESA_TARGET="26.1"

echo ">>> Installing Mesa and open-source Vulkan drivers..."
sudo pacman -Syu --needed --noconfirm \
    mesa mesa-utils libva-mesa-driver mesa-vdpau \
    vulkan-icd-loader vulkan-tools \
    vulkan-intel vulkan-radeon vulkan-nouveau vulkan-swrast vulkan-virtio

INSTALLED_VERSION="$(pacman -Q mesa | awk '{print $2}')"
echo ">>> Installed Mesa version: $INSTALLED_VERSION"

# Arch's Mesa package currently uses an epoch (for example, 1:26.1.6-1).
# Remove it before comparing against the upstream Mesa version target.
UPSTREAM_VERSION="${INSTALLED_VERSION#*:}"
VERSION_COMPARISON="$(vercmp "$UPSTREAM_VERSION" "$MESA_TARGET")"
if (( VERSION_COMPARISON < 0 )); then
    echo "WARNING: Arch currently provides Mesa $INSTALLED_VERSION, older than $MESA_TARGET." >&2
fi

echo ">>> Vulkan driver check:"
vulkaninfo --summary 2>/dev/null \
    | grep -E '(driverVersion|driverID|deviceName)' \
    | head -10 || true

echo ">>> Mesa setup complete. Restart the graphical session to reload drivers."
