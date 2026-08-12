#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-touchid.sh
#
# Enables Touch ID authentication for sudo — the macOS counterpart of
# ../arch/setup-fingerprint.sh and ../debian/setup-fingerprint-debian.sh.
#
# macOS needs no fprintd and no lid check: the Secure Enclave owns the
# fingerprint, and when the lid is closed the Touch ID sensor is unreachable,
# so pam_tid.so simply fails and sudo falls through to the password prompt.
# That is exactly what the pam_check_lid helper reproduces on Linux.
#
# Configuration goes in /etc/pam.d/sudo_local, which macOS includes from
# /etc/pam.d/sudo and preserves across system updates.
#
# pam_reattach is also installed so Touch ID works inside tmux and screen,
# where the sudo process is detached from the GUI session.
#
# Usage: ./setup-touchid.sh
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

if ! bioutil -r >/dev/null 2>&1; then
    echo "WARNING: No Touch ID hardware detected on this Mac." >&2
    echo "         Continuing anyway — the PAM rule is harmless without a sensor." >&2
fi

SUDO_LOCAL="/etc/pam.d/sudo_local"
if [[ ! -f "$SUDO_LOCAL" && ! -f "${SUDO_LOCAL}.template" ]]; then
    echo "ERROR: $SUDO_LOCAL is not supported on this macOS version." >&2
    echo "       Requires macOS 14 (Sonoma) or newer." >&2
    exit 1
fi

###############################################################################
# pam_reattach — lets Touch ID work from tmux/screen sessions
###############################################################################
echo ">>> Installing pam-reattach..."
brew install pam-reattach

PAM_REATTACH="$(brew --prefix)/lib/pam/pam_reattach.so"
if [[ ! -f "$PAM_REATTACH" ]]; then
    echo "ERROR: pam_reattach.so not found at $PAM_REATTACH" >&2
    exit 1
fi

###############################################################################
# Patch /etc/pam.d/sudo_local
#
# Rule order matters: pam_reattach must run before pam_tid so that the Touch ID
# prompt is presented in the GUI session. It is `optional` so a broken or
# missing reattach never blocks sudo.
###############################################################################
if [[ -f "$SUDO_LOCAL" ]] \
    && sudo grep -qE '^[[:space:]]*auth[[:space:]].*pam_tid\.so' "$SUDO_LOCAL"; then
    echo ">>> Touch ID for sudo already configured."
else
    echo ">>> Writing $SUDO_LOCAL..."
    if [[ -f "$SUDO_LOCAL" ]]; then
        sudo cp "$SUDO_LOCAL" "${SUDO_LOCAL}.bak"
        echo "    Original backed up to ${SUDO_LOCAL}.bak"
    fi

    sudo tee "$SUDO_LOCAL" >/dev/null <<SUDO_LOCAL_EOF
# sudo_local: local config file which survives system update and is included for sudo
# Managed by LinuxUtil/mac/setup-touchid.sh
auth       optional       ${PAM_REATTACH}
auth       sufficient     pam_tid.so
SUDO_LOCAL_EOF

    sudo chown root:wheel "$SUDO_LOCAL"
    sudo chmod 444 "$SUDO_LOCAL"
fi

echo ">>> Touch ID setup complete."
echo "    Test it in a new shell: sudo -k && sudo true"
echo "    Enroll fingerprints in System Settings > Touch ID & Password."
