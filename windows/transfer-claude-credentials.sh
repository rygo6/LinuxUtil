#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# transfer-claude-credentials.sh
#
# Transfers this Windows machine's Claude credentials + account/onboarding
# state to another machine, so Claude Code starts already logged in (no login
# prompt).
#
# Requires Claude Code to be installed on the destination first; use the
# appropriate platform's setup-claude.sh. The destination needs python3.
#
# Unlike ../transfer-claude-credentials.sh, this does not use an ssh
# ControlMaster socket, which Git Bash's and MSYS2's ssh do not support
# reliably. Instead the files go over a single connection as a tar stream, so
# there is still only one password prompt.
#
# Usage: ./transfer-claude-credentials.sh user@host
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        echo "       Use ../transfer-claude-credentials.sh elsewhere." >&2
        exit 1
        ;;
esac

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 user@host" >&2
    exit 1
fi

TARGET="$1"

# Claude Code keeps its state in the Windows profile, which is not $HOME
# under MSYS2.
WIN_HOME="$(cygpath -u "$USERPROFILE")"

# `python3` may be the Microsoft Store stub, which exits non-zero, so fall
# back to `python` and the py launcher.
PYTHON=()
for candidate in python3 python "py -3"; do
    if $candidate -c 'import json' >/dev/null 2>&1; then
        read -ra PYTHON <<< "$candidate"
        break
    fi
done
if (( ${#PYTHON[@]} == 0 )); then
    echo "ERROR: Python 3 is not installed." >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d)"
cleanup() {
    rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT

# --- OAuth credentials ---
cp -- "$WIN_HOME/.claude/.credentials.json" "$STAGING_DIR/credentials.json"

# --- Account / onboarding state ---
# The OAuth token alone isn't enough — Claude treats the destination as a fresh,
# un-onboarded install and prompts login unless these account/onboarding keys
# from ~/.claude.json are present too. Copy just those keys (not the whole
# file, which is full of machine-specific project/cache state) and merge them
# into the destination's ~/.claude.json. Python here is a native Windows
# program, so it is given Windows paths.
"${PYTHON[@]}" - "$(cygpath -w "$WIN_HOME/.claude.json")" \
    "$(cygpath -w "$STAGING_DIR/claude-auth-subset.json")" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
keys = ['userID', 'oauthAccount', 'hasCompletedOnboarding', 'lastOnboardingVersion']
json.dump({k: d[k] for k in keys if k in d}, open(sys.argv[2], 'w'))
PY

echo ">>> Transferring Claude credentials and account/onboarding state to $TARGET..."
tar -C "$STAGING_DIR" -cf - credentials.json claude-auth-subset.json \
    | ssh "$TARGET" 'set -e
        tmp="$(mktemp -d)"
        trap "rm -rf \"\$tmp\"" EXIT
        tar -C "$tmp" -xf -
        mkdir -p ~/.claude && chmod 700 ~/.claude
        cp "$tmp/credentials.json" ~/.claude/.credentials.json
        chmod 600 ~/.claude/.credentials.json
        python3 -c "
import json, os, sys
p = os.path.expanduser(\"~/.claude.json\")
base = json.load(open(p)) if os.path.exists(p) else {}
base.update(json.load(open(sys.argv[1])))
json.dump(base, open(p, \"w\"), indent=2)
" "$tmp/claude-auth-subset.json"
        chmod 600 ~/.claude.json'
echo "    Claude credentials transferred."
