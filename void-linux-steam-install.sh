#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Void Linux Steam Install
###############################################################################

# Enable 32-bit repo (required for Steam)
echo ">>> Enabling multilib repository..."
sudo xbps-install -Sy void-repo-multilib

# Install Steam and its udev rules
echo ">>> Installing Steam..."
sudo xbps-install -Sy \
    steam \
    steam-udev-rules

# Install 32-bit Vulkan drivers based on detected GPU
echo ">>> Detecting GPU for 32-bit Vulkan drivers..."
if lspci | grep -qi "VGA.*AMD\|Display.*AMD"; then
    echo "   AMD GPU detected."
    sudo xbps-install -Sy \
        mesa-dri-32bit \
        mesa-vulkan-radeon-32bit \
        vulkan-loader-32bit
elif lspci | grep -qi "VGA.*Intel\|Display.*Intel"; then
    echo "   Intel GPU detected."
    sudo xbps-install -Sy \
        mesa-dri-32bit \
        mesa-vulkan-intel-32bit \
        vulkan-loader-32bit
elif lspci | grep -qi "VGA.*NVIDIA\|Display.*NVIDIA"; then
    echo "   NVIDIA GPU detected."
    sudo xbps-install -Sy \
        mesa-dri-32bit \
        nvidia-libs-32bit \
        vulkan-loader-32bit
else
    echo "   No recognized GPU — installing generic 32-bit Vulkan loader."
    sudo xbps-install -Sy vulkan-loader-32bit
fi

echo ""
echo ">>> Steam installation complete."
echo "   Run 'steam' to launch."
