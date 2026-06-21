#!/bin/bash
###############################################################################
# remote-lib.sh — shared helpers for the setup-*-remote.sh scripts.
#
# Source this file; do not execute it directly. After calling
# `remote_connect user@host` you get:
#
#   $REMOTE      — the user@host target
#   $SSH         — ssh command, pinned to the control socket
#   $SCP         — scp command, pinned to the control socket
#   remote_run   — run a bash payload (read from stdin) on the remote,
#                  allocating a TTY so sudo can prompt.
#
# Connection reuse: if SSH_CONTROL_PATH names an existing control socket
# (setup-dev-tools-remote.sh exports one) it is reused, so you authenticate
# only once across all sub-scripts. Otherwise a private master connection is
# opened here and torn down on exit.
###############################################################################

remote_connect() {
    REMOTE="$1"
    if [ -z "$REMOTE" ]; then
        echo "Usage: $0 user@host" >&2
        exit 1
    fi

    if [ -n "${SSH_CONTROL_PATH:-}" ] && [ -S "${SSH_CONTROL_PATH}" ]; then
        # Reuse the master connection opened by the orchestrator.
        SOCKET="$SSH_CONTROL_PATH"
    else
        # Standalone run: open our own master connection (authenticate once).
        SOCKET="/tmp/ssh-setup-$$"
        ssh -M -f -N -o ControlPath="$SOCKET" "$REMOTE"
        trap 'ssh -O exit -o ControlPath="$SOCKET" "$REMOTE" 2>/dev/null' EXIT
    fi

    SSH="ssh -o ControlPath=$SOCKET"
    SCP="scp -o ControlPath=$SOCKET"
}

# Run a bash script (provided on stdin) on the remote with a TTY so sudo can
# prompt. Usage:
#   remote_run <<'EOF'
#   ... remote commands ...
#   EOF
remote_run() {
    local payload rpath
    payload="$(mktemp)"
    cat > "$payload"
    rpath="/tmp/remote-payload-$$.sh"
    $SCP "$payload" "$REMOTE":"$rpath" >/dev/null
    rm -f "$payload"
    $SSH -t "$REMOTE" "bash '$rpath'; rc=\$?; rm -f '$rpath'; exit \$rc" < /dev/tty
}
