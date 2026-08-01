#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-fingerprint.sh
#
# Installs fprintd and enables fingerprint authentication for Arch local-login
# PAM services while the laptop lid is open. A closed lid skips fingerprint
# authentication and falls through to the normal password stack.
#
# Usage: ./setup-fingerprint.sh
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

echo ">>> Installing fprintd..."
sudo pacman -Syu --needed --noconfirm fprintd python

echo ">>> Installing /usr/local/bin/pam_check_lid..."
sudo tee /usr/local/bin/pam_check_lid >/dev/null <<'LID_CHECK_EOF'
#!/bin/sh
LID_STATE_FILE=$(find /proc/acpi/button/lid -mindepth 2 -maxdepth 2 -name state -print -quit 2>/dev/null)

if [ -z "$LID_STATE_FILE" ]; then
    exit 0
fi

LID_STATE=$(cut -d: -f2 "$LID_STATE_FILE" | tr -d ' ')
case "$LID_STATE" in
    closed) exit 1 ;;
    *)      exit 0 ;;
esac
LID_CHECK_EOF

sudo chown root:root /usr/local/bin/pam_check_lid
sudo chmod 755 /usr/local/bin/pam_check_lid

PAM_FILE="/etc/pam.d/system-local-login"
if [[ ! -f "$PAM_FILE" ]]; then
    echo "ERROR: $PAM_FILE does not exist." >&2
    exit 1
fi

if sudo grep -q 'pam_check_lid' "$PAM_FILE"; then
    echo ">>> Lid-aware fingerprint authentication already configured."
else
    echo ">>> Patching $PAM_FILE..."
    sudo cp "$PAM_FILE" "${PAM_FILE}.bak"

    PATCH_SCRIPT="$(mktemp --suffix=.py)"
    cat > "$PATCH_SCRIPT" <<'PYTHON_EOF'
import sys

path = sys.argv[1]
with open(path) as source:
    lines = source.readlines()

rules = [
    "auth      [success=ignore default=1] pam_exec.so quiet /usr/local/bin/pam_check_lid\n",
    "auth      sufficient                 pam_fprintd.so\n",
]

output = []
inserted = False
for line in lines:
    if not inserted and line.lstrip().startswith("auth"):
        output.extend(rules)
        inserted = True
    output.append(line)

if not inserted:
    raise SystemExit(f"No auth section found in {path}")

with open(path, "w") as destination:
    destination.writelines(output)
PYTHON_EOF

    sudo python3 "$PATCH_SCRIPT" "$PAM_FILE"
    rm -f "$PATCH_SCRIPT"
    echo ">>> Original PAM file backed up to ${PAM_FILE}.bak"
fi

echo ">>> Fingerprint setup complete."
echo "    Enroll: fprintd-enroll"
echo "    Verify: fprintd-verify"
