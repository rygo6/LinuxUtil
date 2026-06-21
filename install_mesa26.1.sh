#!/usr/bin/env bash
set -euo pipefail

# Install Mesa 26.1 via the kisak-mesa PPA.
# Supported Ubuntu releases: 24.04 (Noble), 25.10 (Questing), 26.04 (Resolute).
# Ubuntu 22.04 (Jammy) is discontinued from this PPA — use ppa:kisak/turtle
# (kisak-mesa stable) instead, but that only reaches Mesa 25.0 on Jammy.
# Upgrading to 24.04+ is required for Mesa 26.1.
# kisak-mesa tracks upstream Mesa releases closely and is the standard
# way to get a newer Mesa than Ubuntu ships without building from source.

MESA_TARGET="26.1"

echo "==> Current Mesa version:"
dpkg -l mesa-vulkan-drivers 2>/dev/null | awk '/^ii/{print $3}' || echo "(not installed)"

echo ""
echo "==> Adding kisak-mesa PPA..."
sudo add-apt-repository -y ppa:kisak/kisak-mesa

echo ""
echo "==> Updating package lists..."
sudo apt-get update -qq

echo ""
echo "==> Checking available Mesa version..."
AVAILABLE=$(apt-cache policy mesa-vulkan-drivers | awk '/Candidate:/{print $2}')
echo "    Candidate: $AVAILABLE"

if [[ "$AVAILABLE" < "$MESA_TARGET" ]]; then
    echo ""
    echo "WARNING: PPA candidate ($AVAILABLE) is older than $MESA_TARGET."
    echo "         This Ubuntu release may not have Mesa 26.1 in kisak-mesa."
    echo "         Ubuntu 22.04 is discontinued; upgrade to 24.04+ for Mesa 26.1."
    echo "         Otherwise wait for the PPA to update, or build from source."
    echo "         Proceeding with whatever the PPA provides..."
fi

echo ""
echo "==> Upgrading Mesa packages..."
sudo apt-get install -y --install-recommends \
    mesa-vulkan-drivers \
    libgl1-mesa-dri \
    libglx-mesa0 \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    mesa-utils

echo ""
echo "==> Installed Mesa version:"
dpkg -l mesa-vulkan-drivers | awk '/^ii/{print $3}'

echo ""
echo "==> Vulkan driver check:"
vulkaninfo --summary 2>/dev/null | grep -E "(driverVersion|driverID|deviceName)" | head -10 || true

echo ""
echo "Done. A reboot is not required, but restarting Wayland/X sessions"
echo "will pick up the new driver for running applications."
