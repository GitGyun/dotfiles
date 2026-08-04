#!/bin/bash
set -euo pipefail

# When running under sudo, use the real user's HOME directory
if [[ -n "${SUDO_USER:-}" ]]; then
    if command -v getent &>/dev/null; then
        HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        HOME=$(eval echo "~$SUDO_USER")
    fi
    export HOME
fi

# Only apt/system steps need root. Per-user tooling must run as the invoking
# user: the Claude Code installer hard-refuses to run under sudo, which silently
# skipped it -- and every `claude plugin install` after it -- on sudo installs.
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

#==================================================#
# Installation Profiles:
#   core     - essential shell/editor/tmux + AI tools (default)
#   minimal  - zsh + nvim + git (basic dev environment)
#   standard - minimal + tmux + LSP + plugins
#   full     - standard + AI tools + all LSP plugins
#==================================================#

PROFILE="${1:-core}"
DOT_DIR="$PWD"

echo
echo "=============================================="
echo "  Dotfiles Installation (Profile: $PROFILE)"
echo "=============================================="
echo "  DOT_DIR: $DOT_DIR"
echo "=============================================="

#==================================================#
# Helper functions
#==================================================#
install_minimal() {
    echo
    echo '** [MINIMAL] Installing prerequisite libraries...'
    bash "$DOT_DIR/src/install-prerequisite.sh"

    echo
    echo '** [MINIMAL] Linking configurations...'
    # Xmodmap (Linux only)
    if [[ "$(uname -s)" != "Darwin" ]]; then
        ln -sf "$DOT_DIR/assets/Xmodmap" "$HOME/.Xmodmap"
    fi

    # nvim configuration
    rm -rf "$HOME/.config/nvim"
    mkdir -p "$HOME/.config"
    ln -sfn "$DOT_DIR/nvim" "$HOME/.config/nvim"
    # Drop the core marker so a core -> minimal/standard/full switch loads all plugins
    rm -f "$HOME/.config/nvim-core-profile"

    # shell and git
    # -n: without it, re-running follows the existing ~/.zsh.d symlink and
    # creates the link *inside* the repo (zsh/zsh.d/zsh.d).
    ln -sfn "$DOT_DIR/zsh/zsh.d" "$HOME/.zsh.d"
    ln -sf "$DOT_DIR/git/gitconfig" "$HOME/.gitconfig"
    ln -sf "$DOT_DIR/zsh/zshrc" "$HOME/.zshrc"
    ln -sf "$DOT_DIR/zshenv" "$HOME/.zshenv"
    mkdir -p "$HOME/.config"
    ln -sf "$DOT_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    mkdir -p "$HOME/.ssh"

    # secrets (glab config, gitconfig.secret, ssh config, etc.)
    # as_user: this git-clones and writes 0600 secrets into $HOME. As root those
    # land root-owned and the user cannot read their own secrets; it also needs the
    # user's SSH identity to reach the private repo.
    as_user bash "$DOT_DIR/src/install-secrets.sh" || true

    echo
    echo '** [MINIMAL] Installing oh-my-zsh...'
    bash "$DOT_DIR/src/install-omz.sh"
    ln -sf "$DOT_DIR/assets/mrtazz_custom.zsh-theme" "$HOME/.oh-my-zsh/themes/"

    echo
    echo '** [MINIMAL] Installing zplug...'
    [ -d "$HOME/.zplug" ] || git clone https://github.com/zplug/zplug "$HOME/.zplug"

    echo
    echo '** [MINIMAL] Installing neovim plugins...'
    nvim --headless "+Lazy! install" +qa || true
}

install_standard() {
    install_minimal

    echo
    echo '** [STANDARD] Installing tmux configuration...'
    ln -sf "$DOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    [ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    ln -sf "$DOT_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
    bash ~/.tmux/plugins/tpm/bin/install_plugins || true

    echo
    echo '** [STANDARD] Installing LSP servers via Mason...'
    nvim --headless "+MasonInstall clangd" +qa || true
    nvim --headless "+TSUninstall python" -c "q" || true
}

install_full() {
    install_standard

    echo
    echo '** [FULL] Updating npm to latest...'
    # npm's default global prefix (/usr/local) is not writable by the unprivileged
    # user these installs run as. Own the convention here so `npm install -g` works
    # without sudo on a fresh machine, and so zshrc's ~/.npm-global/bin PATH entry is
    # correct by construction instead of relying on an ambient ~/.npmrc.
    as_user mkdir -p "$HOME/.npm-global"
    as_user npm config set prefix "$HOME/.npm-global"

    # npm 12+ requires Node >= 22, so `npm@latest` only errors out on older Node
    # and leaves the bundled npm in place anyway.
    local node_major
    node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
    if ((node_major >= 22)); then
        as_user npm install -g npm@latest || true
    else
        echo "  Node ${node_major}: keeping the npm bundled with Node ($(npm --version 2>/dev/null || echo unknown))"
    fi

    echo
    echo '** [FULL] Installing OpenAI Codex CLI...'
    as_user npm install -g @openai/codex || true

    echo
    echo '** [FULL] Installing Claude Code...'
    as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || true
    export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

    echo
    echo '** [FULL] Setting up oh-my-claudecode...'
    as_user npm install -g oh-my-claude-sisyphus || true
    as_user claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode || true
    as_user claude plugin install oh-my-claudecode || true

    # Use omc CLI for CLAUDE.md, HUD, and settings setup
    echo '** [FULL] Running omc update for OMC configuration...'
    as_user omc update || true

    echo
    echo '** [FULL] Installing Claude Code LSP plugins...'
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
    echo '** [FULL] Installing superpowers plugin...'
    as_user claude plugin marketplace add obra/superpowers-marketplace || true
    as_user claude plugin install superpowers@superpowers-marketplace || true
}

#==================================================#
# Main installation based on profile
#==================================================#
case "$PROFILE" in
    core)
        DOT_DIR="$DOT_DIR" bash "$DOT_DIR/src/install-core.sh"
        ;;
    minimal)
        install_minimal
        ;;
    standard)
        install_standard
        ;;
    full)
        install_full
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        echo "Usage: $0 [core|minimal|standard|full]"
        exit 1
        ;;
esac

#==================================================#
# Finalize
#==================================================#
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo
    echo '** Fixing DNS resolution (Docker containers)...'
    zsh -c "source '$DOT_DIR/zsh/zsh.d/10-functions.zsh' && fix-dns --force" || true

    echo
    echo '** Setting ZSH as default shell...'
    locale-gen en_US.UTF-8 || true
fi
grep -q "exec zsh" "$HOME/.bash_profile" 2>/dev/null || echo "exec zsh" >> "$HOME/.bash_profile"

# Fix ownership when running under sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    echo '** Fixing file ownership for user '"$SUDO_USER"'...'
    SUDO_GROUP=$(id -gn "$SUDO_USER")
    for dir in "$HOME/.oh-my-zsh" "$HOME/.zplug" "$HOME/.zsh.d" \
               "$HOME/.config" "$HOME/.tmux" "$HOME/.cache/nvim" \
               "$HOME/.cargo" "$HOME/.local" "$HOME/.bun" \
               "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.gitconfig" \
               "$HOME/.Xmodmap" "$HOME/.tmux.conf" "$HOME/.ssh" \
               "$HOME/.jupyter" "$HOME/.claude" "$HOME/.claude.json" \
               "$HOME/.npm" "$HOME/.npm-global"; do
        [[ -e "$dir" ]] && chown -R "$SUDO_USER:$SUDO_GROUP" "$dir"
    done
fi

echo
echo "=============================================="
echo "  Installation complete! (Profile: $PROFILE)"
echo "=============================================="
echo "  Run 'exec zsh' or restart your terminal."
echo "=============================================="
