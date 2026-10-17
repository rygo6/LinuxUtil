#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# transfer-git-credentials.sh
#
# Transfers git credentials (SSH key + gitconfig) from this Windows machine to
# another machine.
#
# Unlike ../transfer-git-credentials.sh, this does not use an ssh
# ControlMaster socket, which Git Bash's and MSYS2's ssh do not support
# reliably. Instead the files go over a single connection as a tar stream, so
# there is still only one password prompt.
#
# Usage: ./transfer-git-credentials.sh user@host
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        echo "       Use ../transfer-git-credentials.sh elsewhere." >&2
        exit 1
        ;;
esac

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 user@host" >&2
    exit 1
fi

TARGET="$1"

# Windows OpenSSH and Git for Windows keep keys and .gitconfig in the Windows
# profile, which is not $HOME under MSYS2.
WIN_HOME="$(cygpath -u "$USERPROFILE")"

for file in .ssh/id_ed25519 .ssh/id_ed25519.pub .gitconfig; do
    if [[ ! -f "$WIN_HOME/$file" ]]; then
        echo "ERROR: $WIN_HOME/$file not found." >&2
        exit 1
    fi
done

echo ">>> Transferring git credentials (SSH key + gitconfig) to $TARGET..."
tar -C "$WIN_HOME" -cf - .ssh/id_ed25519 .ssh/id_ed25519.pub .gitconfig \
    | ssh "$TARGET" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh \
        && tar -C ~ -xf - \
        && chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub'
echo "    Git credentials transferred."
