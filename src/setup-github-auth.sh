#!/bin/bash
set -uo pipefail

#==================================================#
# Optional GitHub authentication
#
# Runs after gh is installed and before install-secrets.sh clones the
# private secrets repo, which is the first step that needs an identity
# GitHub accepts. `gh auth login` is the shortest path: picking SSH makes
# it generate a key and upload it in one go.
#
# Declining -- or a non-interactive run -- is not an error. The install
# continues and secrets can be fetched later with:
#   bash src/install-secrets.sh
#
# Set DOTFILES_SKIP_GH_AUTH=1 to never prompt (unattended installs).
#==================================================#

SECRETS_REPO="${DOTFILES_SECRETS_REPO:-git@github.com:GitGyun/dotfiles-secret.git}"
DOT_DIR="${MYDOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

#==================================================#
# Can we actually reach the secrets repo?
#
# This is the question that matters -- `gh auth status` can be green while
# an SSH-URL remote still fails, and vice versa. BatchMode/accept-new keep
# ssh from blocking the install on an interactive prompt.
#==================================================#
secrets_reachable() {
    timeout 20 env \
        GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10' \
        GIT_TERMINAL_PROMPT=0 \
        git ls-remote --exit-code "$SECRETS_REPO" HEAD >/dev/null 2>&1
}

main() {
    if secrets_reachable; then
        log_success "Secrets repository is reachable; no authentication needed"
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "gh is not installed; skipping GitHub authentication"
        log_info "Register an SSH key manually, then re-run:"
        log_info "  ssh-keygen -t ed25519 -C \"\$(hostname)\" && cat ~/.ssh/id_ed25519.pub"
        log_info "  bash $DOT_DIR/src/install-secrets.sh"
        return 0
    fi

    if [[ -n "${DOTFILES_SKIP_GH_AUTH:-}" ]]; then
        log_info "DOTFILES_SKIP_GH_AUTH set; skipping GitHub authentication"
        return 0
    fi

    if ! gh auth status >/dev/null 2>&1; then
        if [[ ! -t 0 ]]; then
            log_info "Not a terminal; skipping GitHub login"
            log_info "Run later: gh auth login && bash $DOT_DIR/src/install-secrets.sh"
            return 0
        fi

        cat <<EOF

  The private secrets repository is not reachable from this machine yet.
  Authenticating now lets the installer fetch your git identity, SSH
  config, tokens and rclone Drive remote in this same run.

  Pick "SSH" as the git protocol when asked -- gh will generate a key and
  upload it to your account, which is what the secrets repo needs.

EOF
        local reply
        read -r -p "  Authenticate with GitHub now? [Y/n] " reply
        case "$reply" in
            [nN]*)
                log_info "Skipped. Run later: gh auth login && bash $DOT_DIR/src/install-secrets.sh"
                return 0
                ;;
        esac

        gh auth login || log_warn "gh auth login did not complete"
    else
        log_info "gh is already authenticated as $(gh api user --jq .login 2>/dev/null || echo 'unknown')"
    fi

    # Authenticated to GitHub is still not the same as being able to clone
    # the secrets repo over SSH.
    if secrets_reachable; then
        log_success "Secrets repository is now reachable"
        return 0
    fi

    log_warn "Still cannot reach $SECRETS_REPO"
    log_info "The remote is an SSH URL, so this machine needs a key on your account."
    log_info "Re-run 'gh auth login' and choose SSH as the git protocol, then:"
    log_info "  bash $DOT_DIR/src/install-secrets.sh"
    # Deliberately not suggesting `gh auth setup-git` here: ~/.gitconfig is a
    # symlink into this repo by now, and it writes straight through it.
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
