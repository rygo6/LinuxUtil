#!/bin/bash
set -euo pipefail
###############################################################################
# setup-claude-credentials-remote.sh
#
# Copies this machine's Claude credentials + account/onboarding state to a
# remote, so Claude Code starts already logged in (no login prompt).
#
# Requires Claude Code to be installed on the remote first
# (see setup-claude-remote.sh).
#
# Usage: ./setup-claude-credentials-remote.sh user@host
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"
remote_connect "${1:-}"

# --- OAuth credentials ---
echo ">>> Copying Claude credentials to $REMOTE..."
$SSH "$REMOTE" 'mkdir -p ~/.claude && chmod 700 ~/.claude'
$SCP ~/.claude/.credentials.json "$REMOTE":~/.claude/.credentials.json
$SSH "$REMOTE" 'chmod 600 ~/.claude/.credentials.json'

# --- Account / onboarding state ---
# The OAuth token alone isn't enough — Claude treats the remote as a fresh,
# un-onboarded install and prompts login unless these account/onboarding keys
# from ~/.claude.json are present too. Copy just those keys (not the whole
# file, which is full of machine-specific project/cache state) and merge them
# into the remote's ~/.claude.json.
echo ">>> Copying Claude account/onboarding state..."
AUTH_SUBSET="$(mktemp)"
python3 -c "
import json
d = json.load(open('${HOME}/.claude.json'))
keys = ['userID', 'oauthAccount', 'hasCompletedOnboarding', 'lastOnboardingVersion']
json.dump({k: d[k] for k in keys if k in d}, open('${AUTH_SUBSET}', 'w'))
"
$SCP "$AUTH_SUBSET" "$REMOTE":/tmp/claude-auth-subset.json
rm -f "$AUTH_SUBSET"
$SSH "$REMOTE" 'python3 -c "
import json, os
p = os.path.expanduser(\"~/.claude.json\")
base = json.load(open(p)) if os.path.exists(p) else {}
base.update(json.load(open(\"/tmp/claude-auth-subset.json\")))
json.dump(base, open(p, \"w\"), indent=2)
" && chmod 600 ~/.claude.json && rm -f /tmp/claude-auth-subset.json'
echo "    Claude credentials transferred."
