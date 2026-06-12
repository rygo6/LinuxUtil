#!/bin/bash
set -e

###############################################################################
# setup-dev-tools-remote.sh
#
# Provisions a remote Ubuntu/Debian machine over SSH:
#   - latest git + git-lfs (initialized)
#   - copies SSH key + gitconfig (git credentials) from this machine
#   - clang toolchain: clang, asan (via clang/llvm), lldb, clangd
#   - LunarG Vulkan SDK (tarball method, sourced via ~/.bashrc)
#   - VS Code
#   - Claude Code
#   - copies Claude credentials from this machine
#
# Usage: ./setup-dev-tools-remote.sh user@host
###############################################################################

if [ -z "${1:-}" ]; then
    echo "Usage: $0 user@host"
    exit 1
fi

REMOTE="$1"
SOCKET="/tmp/ssh-setup-$$"
REMOTE_SCRIPT="/tmp/remote-devtools-$$.sh"

# Open a persistent connection (authenticates once)
ssh -M -f -N -o ControlPath="$SOCKET" "$REMOTE"
trap 'ssh -O exit -o ControlPath="$SOCKET" "$REMOTE" 2>/dev/null; rm -f "$REMOTE_SCRIPT"' EXIT

SSH="ssh -o ControlPath=$SOCKET"
SCP="scp -o ControlPath=$SOCKET"

###############################################################################
# 1. Copy git credentials (SSH key + gitconfig)
###############################################################################
echo ">>> Copying git credentials (SSH key + gitconfig)..."
$SSH "$REMOTE" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
$SCP ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub "$REMOTE":~/.ssh/
$SCP ~/.gitconfig "$REMOTE":~/.gitconfig
$SSH "$REMOTE" 'chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub'

###############################################################################
# 2. Build the remote provisioning script and run it (with a TTY for sudo)
###############################################################################
cat > "$REMOTE_SCRIPT" <<'REMOTE_EOF'
#!/bin/bash
set -e

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS — /etc/os-release not found." >&2
    exit 1
fi
. /etc/os-release

export DEBIAN_FRONTEND=noninteractive

# --- prerequisites (curl is needed by the Ghostty + Claude installers) ---
echo ">>> Installing prerequisites (curl, ca-certificates, xz-utils)..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates xz-utils

# --- latest git + git-lfs ---
echo ">>> Installing latest git + git-lfs..."
case "${ID:-}" in
    ubuntu)
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:git-core/ppa
        ;;
    debian) ;;
    *)
        echo "ERROR: Unsupported OS '${ID}'. Ubuntu and Debian only." >&2
        exit 1
        ;;
esac
sudo apt-get update
sudo apt-get install -y git git-lfs
# Initialize git-lfs for this user
git lfs install

# --- clang toolchain: clang, asan, lldb, clangd ---
echo ">>> Installing clang toolchain (clang, asan, lldb, clangd)..."
sudo apt-get install -y \
    clang clangd lldb llvm lld \
    clang-tools clang-tidy clang-format \
    libc++-dev libc++abi-dev

# --- LunarG Vulkan SDK (tarball method) ---
# The apt repo only covers jammy/noble and stopped updating after May 2025, so
# we use the version-independent tarball from sdk.lunarg.com.
echo ">>> Installing LunarG Vulkan SDK..."
VULKAN_SDK_VERSION="$(curl -fsSL https://vulkan.lunarg.com/sdk/latest/linux.txt)"
echo "    Latest SDK version: ${VULKAN_SDK_VERSION}"

# SDK build/runtime dependencies (from LunarG getting_started)
sudo apt-get install -y \
    cmake ninja-build pkg-config bison \
    libglm-dev libxcb-dri3-0 libxcb-present0 libpciaccess0 \
    libpng-dev libxcb-keysyms1-dev libxcb-dri3-dev libx11-dev \
    libx11-xcb-dev libxcb-randr0-dev libxcb-ewmh-dev \
    libwayland-dev libxrandr-dev wayland-protocols \
    libxml2-dev liblz4-dev libzstd-dev python3-jsonschema

mkdir -p "${HOME}/vulkan"
if [ ! -d "${HOME}/vulkan/${VULKAN_SDK_VERSION}" ]; then
    sdk_tarball="$(mktemp --suffix=.tar.xz)"
    curl -fsSL "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkan_sdk.tar.xz" \
        -o "$sdk_tarball"
    tar -xf "$sdk_tarball" -C "${HOME}/vulkan"
    rm -f "$sdk_tarball"
else
    echo "    Vulkan SDK ${VULKAN_SDK_VERSION} already extracted — skipping download."
fi

# Source the SDK environment in future shells (replace any prior Vulkan SDK line)
sed -i '\#vulkan/.*/setup-env.sh#d' "$HOME/.bashrc" 2>/dev/null || true
echo "source \"\$HOME/vulkan/${VULKAN_SDK_VERSION}/setup-env.sh\"" >> "$HOME/.bashrc"
echo "    Vulkan SDK env (setup-env.sh) added to ~/.bashrc"

# Copy SDK headers, loader, and layers into system directories (/usr/local).
# Locate files with find since the layout shifts between SDK versions
# (e.g. the loader moved from lib/ to lib/VulkanLoader/lib/ after 1.4.341).
echo ">>> Copying Vulkan SDK files into /usr/local..."
VULKAN_SDK_DIR="${HOME}/vulkan/${VULKAN_SDK_VERSION}/x86_64"

# Headers
sudo cp -r "${VULKAN_SDK_DIR}/include/vulkan/" /usr/local/include/

# Loader (libvulkan.so*) — wherever it lives in this SDK version
loader_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -name 'libvulkan.so*' | head -n1)")"
sudo cp -P "${loader_dir}"/libvulkan.so* /usr/local/lib/

# Layer libraries
layer_lib_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -name 'libVkLayer_*.so' | head -n1)")"
sudo cp "${layer_lib_dir}"/libVkLayer_*.so /usr/local/lib/

# Layer manifests
layer_json_dir="$(dirname "$(find "${VULKAN_SDK_DIR}" -path '*/explicit_layer.d/VkLayer_*.json' | head -n1)")"
sudo mkdir -p /usr/local/share/vulkan/explicit_layer.d
sudo cp "${layer_json_dir}"/VkLayer_*.json /usr/local/share/vulkan/explicit_layer.d/

sudo ldconfig
echo "    Vulkan SDK files copied to /usr/local"

# --- VS Code ---
if ! command -v code >/dev/null 2>&1; then
    echo ">>> Installing VS Code..."
    sudo apt-get install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 \
        /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f /tmp/packages.microsoft.gpg
    sudo apt-get update
    sudo apt-get install -y code
else
    echo ">>> VS Code already installed — skipping."
fi

# --- Ghostty ---
echo ">>> Installing Ghostty..."
case "${ID:-}" in
    ubuntu)
        ghostty_installer="$(mktemp)"
        curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh -o "$ghostty_installer"
        /bin/bash "$ghostty_installer"
        rm -f "$ghostty_installer"
        ;;
    debian)
        curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
            | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
        echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" \
            | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list
        sudo apt-get update
        sudo apt-get install -y ghostty
        ;;
esac

echo ">>> Writing Ghostty config..."
mkdir -p "${HOME}/.config/ghostty"
cat <<'GHOSTTY_EOF' > "${HOME}/.config/ghostty/config"
# Window
window-theme = dark

# Keybindings
keybind = performable:ctrl+c=copy_to_clipboard
keybind = performable:ctrl+v=paste_from_clipboard
keybind = ctrl+shift+w=close_surface

# Splits
split-divider-color = #ff8c42

# Behavior
copy-on-select = false
GHOSTTY_EOF
echo "   Ghostty config written to ~/.config/ghostty/config"

# --- Claude Code ---
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo ">>> Claude Code already installed — skipping."
fi

# Ensure ~/.local/bin (Claude's install location) is on PATH for future shells
if ! grep -qs '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo ">>> Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo ">>> Remote provisioning complete."
REMOTE_EOF

echo ">>> Provisioning dev tools on $REMOTE..."
$SCP "$REMOTE_SCRIPT" "$REMOTE":/tmp/remote-devtools.sh
$SSH -t "$REMOTE" 'bash /tmp/remote-devtools.sh; rm -f /tmp/remote-devtools.sh'

###############################################################################
# 3. Copy Claude credentials + account/onboarding state
###############################################################################
echo ">>> Copying Claude credentials..."
$SSH "$REMOTE" 'mkdir -p ~/.claude && chmod 700 ~/.claude'
$SCP ~/.claude/.credentials.json "$REMOTE":~/.claude/.credentials.json
$SSH "$REMOTE" 'chmod 600 ~/.claude/.credentials.json'

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

echo "Done. Dev tools installed and credentials transferred to $REMOTE"
