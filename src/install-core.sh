#!/bin/bash
set -euo pipefail

DOT_DIR="${DOT_DIR:-$PWD}"

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    export HOME
fi

bash "$DOT_DIR/src/install-core-prerequisite.sh"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Only the apt step above needs root. Run per-user tooling as the invoking user:
# the Claude Code installer hard-refuses to run under sudo ("do not run this
# installer with sudo"), which silently skipped it -- and every `claude plugin
# install` after it -- on any sudo install.
as_user() {
    if [[ -z "${SUDO_USER:-}" || "$(id -u)" -ne 0 ]]; then
        "$@"
        return
    fi
    # Prefer runuser over `sudo -u`: sudo runs PAM account management for the
    # target user and dies with "Account or password is expired" on images where
    # the account has an expired/locked password. runuser skips that check.
    local runuser_bin
    runuser_bin=$(command -v runuser 2>/dev/null || echo /usr/sbin/runuser)
    # /usr/bin/env by absolute path: the uv installer drops a `~/.local/bin/env`
    # PATH-helper script that is meant to be sourced, and it shadows the real env
    # for anything whose PATH starts with ~/.local/bin -- silently swallowing the
    # command and exiting 0.
    if [[ -x "$runuser_bin" ]]; then
        "$runuser_bin" -u "$SUDO_USER" -- /usr/bin/env HOME="$HOME" PATH="$PATH" "$@"
    else
        sudo -u "$SUDO_USER" -H /usr/bin/env PATH="$PATH" "$@"
    fi
}

echo
echo '** [CORE] Linking configurations...'
if [[ "$(uname -s)" != "Darwin" ]]; then
    ln -sf "$DOT_DIR/assets/Xmodmap" "$HOME/.Xmodmap"
fi
rm -rf "$HOME/.config/nvim"
mkdir -p "$HOME/.config" "$HOME/.ssh"
ln -sfn "$DOT_DIR/nvim" "$HOME/.config/nvim"
: > "$HOME/.config/nvim-core-profile"
# -n: without it, re-running follows the existing ~/.zsh.d symlink and
# creates the link *inside* the repo (zsh/zsh.d/zsh.d).
ln -sfn "$DOT_DIR/zsh/zsh.d" "$HOME/.zsh.d"
ln -sf "$DOT_DIR/git/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOT_DIR/zsh/zshrc" "$HOME/.zshrc"
ln -sf "$DOT_DIR/zshenv" "$HOME/.zshenv"
ln -sf "$DOT_DIR/config/starship.toml" "$HOME/.config/starship.toml"

echo
echo '** [CORE] Checking GitHub authentication...'
# Before the secrets step, not after: this is what makes the private repo
# reachable in this same run. Optional -- it never fails the install.
as_user bash "$DOT_DIR/src/setup-github-auth.sh" || true

echo
echo '** [CORE] Installing selected secrets...'
# as_user: this git-clones and writes 0600 secrets into $HOME. As root those
# land root-owned and the user cannot read their own secrets; it also needs the
# user's SSH identity to reach the private repo.
as_user bash "$DOT_DIR/src/install-secrets.sh" --core || true

# The secrets repo normally ships a ready rclone.conf, so there is nothing to
# do here. Only the first machine (or one whose token was revoked) needs the
# interactive OAuth flow -- point at it instead of blocking the install.
if ! as_user rclone listremotes 2>/dev/null | grep -qx 'mydrive:'; then
    echo "** [CORE] No 'mydrive' rclone remote yet."
    echo "**        Set it up once with: bash $DOT_DIR/src/setup-rclone-drive.sh"
fi

echo
echo '** [CORE] Installing Oh My Zsh...'
bash "$DOT_DIR/src/install-omz.sh"
ln -sf "$DOT_DIR/assets/mrtazz_custom.zsh-theme" "$HOME/.oh-my-zsh/themes/"

echo
echo '** [CORE] Installing tmux configuration and all plugins...'
ln -sf "$DOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.tmux"
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
ln -sf "$DOT_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
bash "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true

echo
echo '** [CORE] Installing selected Neovim plugins...'
nvim --headless "+Lazy! install" +qa || true

echo
echo '** [CORE] Updating npm and installing OpenAI Codex CLI...'
# npm's default global prefix (/usr/local) is not writable by the unprivileged
# user these installs run as. Own the convention here so `npm install -g` works
# without sudo on a fresh machine, and so zshrc's ~/.npm-global/bin PATH entry is
# correct by construction instead of relying on an ambient ~/.npmrc.
as_user mkdir -p "$HOME/.npm-global"
as_user npm config set prefix "$HOME/.npm-global"

# npm 12+ requires Node >= 22, so `npm@latest` only errors out on the pinned
# Node 20 and leaves the bundled npm in place anyway. Chase latest only when the
# installed Node can actually run it.
node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
if ((node_major >= 22)); then
    as_user npm install -g npm@latest || true
else
    echo "** [CORE] Node ${node_major}: keeping the npm bundled with Node ($(npm --version 2>/dev/null || echo unknown))"
fi
as_user npm install -g @openai/codex || true

echo
echo '** [CORE] Installing Claude Code...'
as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || true

echo
echo '** [CORE] Setting up oh-my-claudecode...'
as_user npm install -g oh-my-claude-sisyphus || true
as_user claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode || true
as_user claude plugin install oh-my-claudecode || true
as_user omc update || true

echo
echo '** [CORE] Installing all Claude Code LSP plugins...'
as_user claude plugin marketplace add anthropics/claude-plugins-official || true
as_user claude plugin install typescript-lsp@claude-plugins-official || true
as_user claude plugin install pyright-lsp@claude-plugins-official || true
as_user claude plugin install gopls-lsp@claude-plugins-official || true
as_user claude plugin install rust-analyzer-lsp@claude-plugins-official || true
as_user claude plugin install clangd-lsp@claude-plugins-official || true
as_user claude plugin install lua-lsp@claude-plugins-official || true
as_user claude plugin install csharp-lsp@claude-plugins-official || true
as_user claude plugin install php-lsp@claude-plugins-official || true
as_user claude plugin install swift-lsp@claude-plugins-official || true
as_user claude plugin install jdtls-lsp@claude-plugins-official || true

echo
echo '** [CORE] Installing superpowers plugin...'
as_user claude plugin marketplace add obra/superpowers-marketplace || true
as_user claude plugin install superpowers@superpowers-marketplace || true
