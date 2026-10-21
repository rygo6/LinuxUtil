#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-agent-skills.sh
#
# Installs all rygo6 *-AGENTS skills used on this machine into ~/.agents/skills
# and links them into ~/.claude/skills and ~/.codex/skills, per each repo's
# README.
#
#   concise  https://github.com/rygo6/Concise-AGENTS   (no submodules)
#   metal    https://github.com/rygo6/Metal-AGENTS
#   opengl   https://github.com/rygo6/OpenGL-AGENTS
#   openxr   https://github.com/rygo6/OpenXR-AGENTS
#   vulkan   https://github.com/rygo6/Vulkan-AGENTS
#   webgl    https://github.com/rygo6/WebGL-AGENTS
#   webxr    https://github.com/rygo6/WebXR-AGENTS
#
# The reference repos are git submodules and are large — a full install pulls
# several GB. Re-running the script updates existing clones instead of
# recloning. Submodules are initialized one level deep only; recursing into
# them pulls tens of GB of build dependencies that no skill ever references,
# and ANGLE's nested submodules fail outright on chrome-internal.googlesource.com.
#
# Clones over SSH, so an SSH key must be registered with GitHub; keys can be
# copied from another machine with ../transfer-git-credentials.sh.
#
# Windows differences from ../setup-agent-skills.sh:
#   - Paths are rooted at %USERPROFILE%, where Claude Code and Codex look,
#     because MSYS2's $HOME is not the Windows profile directory.
#   - Skills are linked with NTFS directory junctions. Depending on the
#     MSYS winsymlinks setting, `ln -s` either needs Developer Mode or
#     silently makes a copy, while junctions need no special privilege.
#   - core.longpaths is enabled, since the reference submodules contain paths
#     longer than Windows' 260-character MAX_PATH.
#
# Usage: ./setup-agent-skills.sh [skill...]     (default: all of them)
###############################################################################

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *)
        echo "ERROR: This script supports Windows (Git Bash or MSYS2) only." >&2
        echo "       Use ../setup-agent-skills.sh elsewhere." >&2
        exit 1
        ;;
esac

# USERPROFILE is missing when one MSYS runtime starts another (e.g. MSYS2's
# bash from Git Bash), so fall back to asking Windows for the profile folder.
WIN_HOME="$(cygpath -u "${USERPROFILE:-$(cygpath -w -F 40)}")"
AGENTS_DIR="$WIN_HOME/.agents/skills"
LINK_DIRS=("$WIN_HOME/.claude/skills" "$WIN_HOME/.codex/skills")
REPO_OWNER="rygo6"

# skill|repo|submodules
SKILLS=(
    "concise|Concise-AGENTS|no"
    "metal|Metal-AGENTS|yes"
    "opengl|OpenGL-AGENTS|yes"
    "openxr|OpenXR-AGENTS|yes"
    "vulkan|Vulkan-AGENTS|yes"
    "webgl|WebGL-AGENTS|yes"
    "webxr|WebXR-AGENTS|yes"
)

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed." >&2
    exit 1
fi

reset_gitlinks() {
    local repo="$1"
    local sm

    [[ -f "$repo/.gitmodules" ]] || return 0

    while read -r _ sm; do
        [[ -n "$sm" ]] || continue
        git -C "$repo" checkout -- "$sm" 2>/dev/null || true
    done < <(git config -f "$repo/.gitmodules" --get-regexp '^submodule\..*\.path$' || true)
}

selected=()
if [[ $# -gt 0 ]]; then
    selected=("$@")
else
    for entry in "${SKILLS[@]}"; do
        selected+=("${entry%%|*}")
    done
fi

for name in "${selected[@]}"; do
    repo=""
    submodules=""
    for entry in "${SKILLS[@]}"; do
        IFS='|' read -r s r m <<< "$entry"
        if [[ "$s" == "$name" ]]; then
            repo="$r"
            submodules="$m"
            break
        fi
    done

    if [[ -z "$repo" ]]; then
        echo "ERROR: Unknown skill '$name'. Known skills:" >&2
        for entry in "${SKILLS[@]}"; do
            echo "    ${entry%%|*}" >&2
        done
        exit 1
    fi

    dest="$AGENTS_DIR/$name"
    expected_ssh="git@github.com:$REPO_OWNER/$repo.git"
    expected_https="https://github.com/$REPO_OWNER/$repo.git"

    if [[ -d "$dest/.git" ]]; then
        origin="$(git -C "$dest" remote get-url origin 2>/dev/null || true)"
        if [[ "$origin" != "$expected_ssh" &&
              "$origin" != "$expected_https" &&
              "$origin" != "${expected_https%.git}" ]]; then
            echo "ERROR: $dest is not the expected $REPO_OWNER/$repo clone." >&2
            echo "    Found origin: ${origin:-<none>}" >&2
            echo "    Expected: $expected_ssh" >&2
            exit 1
        fi
        echo ">>> Updating $name in $dest..."
        reset_gitlinks "$dest"
        git -C "$dest" fetch --prune origin
        upstream="$(git -C "$dest" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
        if [[ -z "$upstream" ]]; then
            upstream="origin/master"
        fi
        if ! git -C "$dest" merge --ff-only "$upstream"; then
            echo "ERROR: $dest could not fast-forward to $upstream." >&2
            echo "    Resolve it by hand, then re-run this script." >&2
            exit 1
        fi
    elif [[ -e "$dest" ]]; then
        echo "ERROR: $dest exists but is not a git clone." >&2
        exit 1
    else
        echo ">>> Cloning $repo into $dest..."
        mkdir -p "$AGENTS_DIR"
        git -c core.longpaths=true clone "$expected_ssh" "$dest"
    fi
    git -C "$dest" config core.longpaths true

    if [[ "$submodules" == "yes" ]]; then
        echo ">>> Updating $name reference submodules..."
        git -C "$dest" -c core.longpaths=true submodule update --init --remote
    fi

    if [[ ! -f "$dest/SKILL.md" ]]; then
        echo "ERROR: $dest does not contain SKILL.md." >&2
        exit 1
    fi

    # MSYS reports both junctions and symlinks as -L. They are removed with
    # cmd's rmdir, which unlinks the reparse point without touching the
    # target; `rm -rf` on a junction would recurse into the clone.
    # MSYS2_ARG_CONV_EXCL stops MSYS from rewriting /J and /c as paths, and
    # cmd.exe is named in full because MSYS2's /usr/bin/cmd wraps $COMSPEC.
    for link_dir in "${LINK_DIRS[@]}"; do
        link="$link_dir/$name"
        if [[ -e "$link" && ! -L "$link" ]]; then
            echo "ERROR: $link exists and is not a link — leaving it." >&2
            exit 1
        fi
        mkdir -p "$link_dir"
        if [[ -L "$link" ]]; then
            MSYS2_ARG_CONV_EXCL='*' cmd.exe /c rmdir "$(cygpath -w "$link")"
        fi
        MSYS2_ARG_CONV_EXCL='*' cmd.exe /c mklink /J \
            "$(cygpath -w "$link")" "$(cygpath -w "$dest")" >/dev/null
        echo "    Linked $link -> $dest"
    done
done

echo ">>> Agent skills install complete."
printf "    Installed:"
printf " /%s" "${selected[@]}"
printf '\n'
