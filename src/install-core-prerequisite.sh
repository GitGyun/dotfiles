#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "The core profile currently supports apt-based Linux only." >&2
    exit 1
fi

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    export HOME
fi

DOT_DIR="${MYDOTFILES:-$PWD}"
[[ -f "$DOT_DIR/config/versions.sh" ]] && source "$DOT_DIR/config/versions.sh"

export DEBIAN_FRONTEND=noninteractive
echo '** [CORE] Updating apt metadata...'
apt-get update -qq

echo '** [CORE] Installing required apt packages...'
# git: Oh My Zsh, zinit, TPM, Lazy.nvim, and secrets
# curl/ca-certificates: Node.js, Claude Code, and DNS checks
# tar/gzip: prebuilt Neovim archive
# bc/procps: tmux status bar and DNS process checks
# fzf/xclip: configured tmux plugins and clipboard integration
# ripgrep: Telescope live-grep
# fd-find/bat: FZF_DEFAULT_COMMAND and the `bat` alias in zsh.d
# locales: en_US.UTF-8 configured by install.sh
# dnsmasq: split DNS optimization
# unzip: rclone is distributed as a zip archive
apt-get install -y -qq \
    zsh tmux git curl ca-certificates tar gzip unzip \
    bc procps fzf xclip ripgrep fd-find bat locales dnsmasq

echo '** [CORE] Installing Node.js...'
curl -fsSL "https://deb.nodesource.com/setup_${VERSION_NODE:-20}.x" | bash -

# Ubuntu/Debian split Node into nodejs + libnode-dev + npm. NodeSource's single
# nodejs package ships the same /usr/include/node/* headers as libnode-dev, so
# dpkg aborts with "trying to overwrite ... which is also in package libnode-dev"
# on any image that preinstalled the distro Node. Drop the conflicting ones
# first; the NodeSource package supplies its own headers and npm.
conflicting_node_pkgs=()
for pkg in libnode-dev npm nodejs-doc; do
    if [[ "$(dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null)" == "installed" ]]; then
        conflicting_node_pkgs+=("$pkg")
    fi
done
if ((${#conflicting_node_pkgs[@]})); then
    echo "** [CORE] Removing distro Node packages that conflict with NodeSource: ${conflicting_node_pkgs[*]}"
    apt-get remove -y -qq "${conflicting_node_pkgs[@]}"
fi

apt-get install -y -qq nodejs

echo '** [CORE] Installing prebuilt Neovim...'
case "$(uname -m)" in
    x86_64|amd64)
        nvim_arch="x86_64"
        eza_arch="x86_64"
        rclone_arch="amd64"
        ;;
    aarch64|arm64)
        nvim_arch="arm64"
        eza_arch="aarch64"
        rclone_arch="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

nvim_version="${VERSION_NEOVIM:-v0.11.3}"
nvim_archive="nvim-linux-${nvim_arch}.tar.gz"
nvim_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/${nvim_archive}"
nvim_root="$HOME/.local/opt"
nvim_dest="$nvim_root/nvim-${nvim_version}"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$nvim_root" "$HOME/.local/bin"
curl -fsSL "$nvim_url" -o "$tmp_dir/$nvim_archive"
tar -xzf "$tmp_dir/$nvim_archive" -C "$tmp_dir"
rm -rf "$nvim_dest"
mv "$tmp_dir/nvim-linux-${nvim_arch}" "$nvim_dest"
ln -sfn "$nvim_dest/bin/nvim" "$HOME/.local/bin/nvim"

echo "** [CORE] Neovim ${nvim_version} installed at $nvim_dest"

echo '** [CORE] Installing modern CLI tools...'

# fd: Debian/Ubuntu ships the binary as `fdfind`, but zshrc's
# FZF_DEFAULT_COMMAND calls `fd` directly (not through an alias).
if command -v fdfind >/dev/null 2>&1; then
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# eza (ls replacement): prebuilt binary, avoids pulling in Rust/cargo
if [[ "${VERSION_EZA:-latest}" == "latest" ]]; then
    eza_url="https://github.com/eza-community/eza/releases/latest/download/eza_${eza_arch}-unknown-linux-gnu.tar.gz"
else
    eza_url="https://github.com/eza-community/eza/releases/download/${VERSION_EZA}/eza_${eza_arch}-unknown-linux-gnu.tar.gz"
fi
if curl -fsSL "$eza_url" -o "$tmp_dir/eza.tar.gz"; then
    tar -xzf "$tmp_dir/eza.tar.gz" -C "$tmp_dir"
    install -m 755 "$tmp_dir/eza" "$HOME/.local/bin/eza"
    echo "** [CORE] eza installed at $HOME/.local/bin/eza"
else
    echo "[WARN] Could not download eza from $eza_url" >&2
fi

# zoxide (smart cd): official installer, targets ~/.local/bin
if command -v zoxide >/dev/null 2>&1; then
    echo '** [CORE] zoxide already installed, skipping'
else
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh \
        || echo '[WARN] zoxide installation failed' >&2
fi

# starship (prompt): config is symlinked by install-core.sh
if command -v starship >/dev/null 2>&1; then
    echo '** [CORE] starship already installed, skipping'
else
    curl -sSfL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" \
        || echo '[WARN] starship installation failed' >&2
fi

# rclone (Google Drive sync): prebuilt binary, same reasoning as eza above.
# The Drive remote itself comes from the secrets repo, or from
# src/setup-rclone-drive.sh on the first machine.
if command -v rclone >/dev/null 2>&1; then
    echo '** [CORE] rclone already installed, skipping'
else
    rclone_version="${VERSION_RCLONE:-current}"
    if [[ "$rclone_version" == "current" ]]; then
        rclone_url="https://downloads.rclone.org/rclone-current-linux-${rclone_arch}.zip"
    else
        rclone_url="https://downloads.rclone.org/${rclone_version}/rclone-${rclone_version}-linux-${rclone_arch}.zip"
    fi
    # The archive nests the binary under rclone-<version>-linux-<arch>/
    if curl -fsSL "$rclone_url" -o "$tmp_dir/rclone.zip" \
        && unzip -q -o "$tmp_dir/rclone.zip" -d "$tmp_dir/rclone"; then
        install -m 755 "$tmp_dir"/rclone/rclone-*/rclone "$HOME/.local/bin/rclone"
        echo "** [CORE] rclone installed at $HOME/.local/bin/rclone"
    else
        echo "[WARN] Could not download rclone from $rclone_url" >&2
    fi
fi
