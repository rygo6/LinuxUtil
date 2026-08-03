#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-agent-skills.sh
#
# Installs the rygo6 *-AGENTS skills into ~/.agents/skills and links them into
# ~/.claude/skills and ~/.codex/skills, per each repo's README.
#
#   concise  https://github.com/rygo6/Concise-AGENTS   (no submodules)
#   openxr   https://github.com/rygo6/OpenXR-AGENTS
#   vulkan   https://github.com/rygo6/Vulkan-AGENTS
#   webxr    https://github.com/rygo6/WebXR-AGENTS
#
# The reference repos are git submodules and are large — a full install pulls
# several GB. Re-running the script updates existing clones instead of
# recloning.
#
# Clones over SSH, so an SSH key must be registered with GitHub; keys can be
# copied from another machine with ./transfer-git-credentials.sh.
#
# Usage: ./setup-agent-skills.sh [skill...]     (default: all of them)
###############################################################################

AGENTS_DIR="$HOME/.agents/skills"
LINK_DIRS=("$HOME/.claude/skills" "$HOME/.codex/skills")

# skill|repo|submodules
SKILLS=(
    "concise|Concise-AGENTS|no"
    "openxr|OpenXR-AGENTS|yes"
    "vulkan|Vulkan-AGENTS|yes"
    "webxr|WebXR-AGENTS|yes"
)

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed." >&2
    exit 1
fi

selected=("$@")
if [[ ${#selected[@]} -eq 0 ]]; then
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

    if [[ -d "$dest/.git" ]]; then
        echo ">>> Updating $name in $dest..."
        git -C "$dest" pull --ff-only
    elif [[ -e "$dest" ]]; then
        echo "ERROR: $dest exists but is not a git clone." >&2
        exit 1
    else
        echo ">>> Cloning $repo into $dest..."
        mkdir -p "$AGENTS_DIR"
        if [[ "$submodules" == "yes" ]]; then
            git clone --recurse-submodules \
                "git@github.com:rygo6/$repo.git" "$dest"
        else
            git clone "git@github.com:rygo6/$repo.git" "$dest"
        fi
    fi

    if [[ "$submodules" == "yes" ]]; then
        echo ">>> Updating $name reference submodules..."
        git -C "$dest" submodule update --init --remote
    fi

    for link_dir in "${LINK_DIRS[@]}"; do
        link="$link_dir/$name"
        if [[ -e "$link" && ! -L "$link" ]]; then
            echo "ERROR: $link exists and is not a symlink — leaving it." >&2
            exit 1
        fi
        mkdir -p "$link_dir"
        ln -sfn "$dest" "$link"
        echo "    Linked $link -> $dest"
    done
done

echo ">>> Agent skills install complete."
echo "    Invoke them with /concise, /openxr, /vulkan, /webxr."
