#!/bin/bash
set -euo pipefail
###############################################################################
# transfer-claude-credentials.sh
#
# Transfers this machine's Claude credentials + account/onboarding state to
# another machine, so Claude Code starts already logged in (no login prompt).
#
# Requires Claude Code to be installed on the destination first; use the
# appropriate distro's setup-claude.sh.
#
# Usage: ./transfer-claude-credentials.sh user@host
###############################################################################

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 user@host" >&2
    exit 1
fi

TARGET="$1"
SOCKET="/tmp/ssh-transfer-$$"

ssh -M -f -N -o ControlPath="$SOCKET" "$TARGET"

cleanup() {
    ssh -O exit -o ControlPath="$SOCKET" "$TARGET" 2>/dev/null || true
}
trap cleanup EXIT

SSH=(ssh -o "ControlPath=$SOCKET")
SCP=(scp -o "ControlPath=$SOCKET")

# --- OAuth credentials ---
echo ">>> Transferring Claude credentials to $TARGET..."
"${SSH[@]}" "$TARGET" 'mkdir -p ~/.claude && chmod 700 ~/.claude'
"${SCP[@]}" "$HOME/.claude/.credentials.json" \
    "$TARGET":~/.claude/.credentials.json
"${SSH[@]}" "$TARGET" 'chmod 600 ~/.claude/.credentials.json'

# --- Account / onboarding state ---
# The OAuth token alone isn't enough — Claude treats the destination as a fresh,
# un-onboarded install and prompts login unless these account/onboarding keys
# from ~/.claude.json are present too. Copy just those keys (not the whole
# file, which is full of machine-specific project/cache state) and merge them
# into the destination's ~/.claude.json.
echo ">>> Transferring Claude account/onboarding state..."
AUTH_SUBSET="$(mktemp)"
python3 -c "
import json
d = json.load(open('${HOME}/.claude.json'))
keys = ['userID', 'oauthAccount', 'hasCompletedOnboarding', 'lastOnboardingVersion']
json.dump({k: d[k] for k in keys if k in d}, open('${AUTH_SUBSET}', 'w'))
"
"${SCP[@]}" "$AUTH_SUBSET" "$TARGET":/tmp/claude-auth-subset.json
rm -f "$AUTH_SUBSET"
"${SSH[@]}" "$TARGET" 'python3 -c "
import json, os
p = os.path.expanduser(\"~/.claude.json\")
base = json.load(open(p)) if os.path.exists(p) else {}
base.update(json.load(open(\"/tmp/claude-auth-subset.json\")))
json.dump(base, open(p, \"w\"), indent=2)
" && chmod 600 ~/.claude.json && rm -f /tmp/claude-auth-subset.json'
echo "    Claude credentials transferred."
