#!/bin/bash
# =============================================================================
# Debian Fingerprint Auth Setup
# =============================================================================
#
# Installs fprintd and configures PAM so fingerprint auth is offered when the
# lid is open, and automatically falls back to password when the lid is closed.
#
# Run as your normal user (uses sudo where needed).
# After running, enroll your fingerprint with: fprintd-enroll
#
# Supported: Debian 12/13, Ubuntu 22.04/24.04
# =============================================================================

set -e

###############################################################################
# Install fprintd
###############################################################################
echo ">>> Installing fprintd..."
sudo apt-get update -q
sudo apt-get install -y fprintd libpam-fprintd

###############################################################################
# Enable fprintd in PAM via pam-auth-update
###############################################################################
echo ">>> Enabling fprintd in PAM..."
sudo pam-auth-update --enable fprintd

###############################################################################
# Create lid-state check script
#
# Called by pam_exec.so before pam_fprintd.so. Exits 0 (lid open — try
# fingerprint) or 1 (lid closed — skip fingerprint, fall through to password).
# Handles variable LID device names (LID, LID0, etc.) and desktops with no
# lid device.
###############################################################################
echo ">>> Installing /usr/local/bin/pam_check_lid..."
sudo tee /usr/local/bin/pam_check_lid > /dev/null << 'SCRIPT'
#!/bin/sh
LID_STATE_FILE=$(ls /proc/acpi/button/lid/*/state 2>/dev/null | head -1)

if [ -z "$LID_STATE_FILE" ]; then
    exit 0  # No lid device — assume open (desktop)
fi

LID_STATE=$(cut -d':' -f2 "$LID_STATE_FILE" | tr -d ' ')

case $LID_STATE in
    closed) exit 1 ;;
    *)      exit 0 ;;
esac
SCRIPT

sudo chown root:root /usr/local/bin/pam_check_lid
sudo chmod 755 /usr/local/bin/pam_check_lid

###############################################################################
# Patch /etc/pam.d/common-auth
#
# Inserts the pam_exec lid check on the line immediately before pam_fprintd.
# The jump counts on pam_fprintd and later modules are unaffected because the
# new line sits before fprintd, not after it.
#
# Result:
#   auth  [success=ignore default=1]  pam_exec.so quiet /usr/local/bin/pam_check_lid
#   auth  [success=N default=ignore]  pam_fprintd.so ...
#   auth  [success=... ]              pam_unix.so ...
#   ...
###############################################################################
PAM_FILE="/etc/pam.d/common-auth"

if sudo grep -q "pam_check_lid" "$PAM_FILE"; then
    echo ">>> Lid check already present in $PAM_FILE — skipping"
else
    echo ">>> Patching $PAM_FILE..."
    sudo cp "$PAM_FILE" "${PAM_FILE}.bak"

    TMP_PY=$(mktemp /tmp/patch_pam.XXXXXX.py)
    cat > "$TMP_PY" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out = []
inserted = False
for line in lines:
    if not inserted and 'pam_fprintd.so' in line:
        out.append('auth\t[success=ignore default=1]\tpam_exec.so quiet /usr/local/bin/pam_check_lid\n')
        inserted = True
    out.append(line)
with open(path, 'w') as f:
    f.writelines(out)
PYEOF

    sudo python3 "$TMP_PY" "$PAM_FILE"
    rm "$TMP_PY"
    echo ">>> Original backed up to ${PAM_FILE}.bak"
fi

echo ""
echo ">>> Done. Next steps:"
echo "    1. Enroll your fingerprint:"
echo "       fprintd-enroll"
echo "    2. Test without committing (optional):"
echo "       pamtester common-auth \$(whoami) authenticate"
