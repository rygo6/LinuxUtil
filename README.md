# Void Linux GNOME

A single-script installer that sets up a complete GNOME desktop environment on a fresh Void Linux base install. Run it once after a minimal Void Linux installation and reboot into a fully configured desktop.

## What It Does

- **Desktop environment** — Installs GNOME with GDM, Xorg, XDG portals, and GNOME browser connector
- **Networking** — NetworkManager with VPN plugins (OpenVPN, OpenConnect, VPNC, L2TP)
- **Audio** — PipeWire + WirePlumber (replaces PulseAudio), with ALSA compatibility
- **Bluetooth** — BlueZ with PipeWire audio support (libspa-bluetooth)
- **Printing** — CUPS with filters, Foomatic, and Gutenprint drivers
- **GPU drivers** — Auto-detects AMD, Intel, and NVIDIA hardware via `lspci` and installs the correct drivers, Vulkan support, and video acceleration
- **Fingerprint reader** — Auto-detects via `lsusb` and configures fprintd with PAM for GDM, sudo, polkit, and console login
- **Framework Laptop fixes** — Auto-detects Framework hardware and applies known fixes (audio pop, Wi-Fi stability, display flickering, brightness keys, TLP/PPD selection)
- **Theming** — Fluent GTK theme, Fluent icon theme (grey), Borealis cursors, Inter + JetBrains Mono + ShureTechMono Nerd fonts
- **GNOME extensions** — Clipboard History, Dash to Dock, Disconnect Wifi, Frippery Move Clock, Hibernate Status Button, Printers, Resource Monitor
- **Wallpapers + GRUB theme** — Void Linux artwork (bundled in `artwork/`)
- **Hibernate on lid close** — Configures GRUB resume, dracut, elogind, and polkit for swap-based hibernation
- **Flatpak** — Flathub repository with GNOME Software integration
- **Services** — Enables GDM, D-Bus, elogind, NetworkManager, Bluetooth, CUPS, cronie, chronyd, TLP, and SSH; disables conflicting acpid/dhcpcd/wpa_supplicant

## Prerequisites

- Fresh Void Linux install from the **base** live image (not Xfce)
- Installed via `void-installer` with "Network" source
- A non-root user in the `wheel` group with sudo access
- System boots to TTY with networking functional

## Usage

```bash
git clone https://github.com/rygo6/Void-Linux-Gnome.git
cd Void-Linux-Gnome
chmod +x void-linux-gnome-installer.sh
./void-linux-gnome-installer.sh
```

Review the script before running — comment out any sections you don't need.

## Repository Structure

```
.
├── void-linux-gnome-installer.sh   # Main installer script
├── artwork/                        # Void Linux wallpapers + GRUB theme (CC-BY-4.0)
│   ├── wallpapers/                 # 5 high-res Void Linux wallpapers
│   ├── grub/themes/void3/          # Void GRUB bootloader theme
│   ├── LICENSE                     # CC-BY-4.0 license
│   └── README.md                   # Artwork attribution and source info
└── README.md                       # This file
```

## Sources

This script is based on and extends the following guides, updated to follow the official Void Linux Handbook:

- [Reddit: Void + GNOME guide](https://reddit.com/r/voidlinux/comments/1ar05zg/guide_void_gnome/)
- [Gist: nerdyslacker Void + GNOME](https://gist.github.com/nerdyslacker/398671398915888f977b8bddb33ab1f1)
- [The Void Linux Handbook](https://docs.voidlinux.org/)

Key changes from the source guides are documented in the script header (PipeWire over PulseAudio, Bluetooth config, NetworkManager groups, acpid/elogind conflict, GDM testing, GPU auto-detection, fingerprint auto-detection).

Artwork sourced from [oSoWoSo/void-artwork](https://github.com/oSoWoSo/void-artwork) under [CC-BY-4.0](artwork/LICENSE).
