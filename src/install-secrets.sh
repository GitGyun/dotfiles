#!/bin/bash
set -uo pipefail

#==================================================#
# Fetch and install secrets from private GitLab repo
#
# Usage:
#   bash src/install-secrets.sh          # fetch & install
#   bash src/install-secrets.sh --save   # collect & push
#
# Repo: Create a private repo on GitHub first
#==================================================#

SECRETS_REPO="${DOTFILES_SECRETS_REPO:-git@github.com:GitGyun/dotfiles-secret.git}"
SECRETS_DIR="${HOME}/dotfiles-secret"

#==================================================#
# Color
#==================================================#
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#==================================================#
# Secret file mapping
# Format: "path_in_repo:destination:permissions"
#
# Layout of the secrets repo (paths mirror the destination structure):
#   git/gitconfig.secret
#   ssh/config
#   config/{netrc,huggingface/token,wandb/settings}
#   config/rclone/{rclone.conf,gcp-oauth.env}
#
# CLI auth tokens (gh, glab) are deliberately NOT synced: they cannot
# bootstrap anything (they live inside the repo they grant access to),
# and each machine should authenticate on its own.
#
# Entries whose source file is absent from the repo are skipped on
# install, and picked up by --save once they exist locally.
#
# Add new secrets here:
#==================================================#
SECRET_MAP=(
    "git/gitconfig.secret:${HOME}/.gitconfig.secret:600"
    "ssh/config:${HOME}/.ssh/config:600"
    "config/netrc:${HOME}/.netrc:600"
    "config/huggingface/token:${HOME}/.cache/huggingface/token:600"
    "config/wandb/settings:${HOME}/.config/wandb/settings:600"
    # rclone.conf carries the Drive OAuth token, so a new machine gets a
    # working `mydrive` remote with no interaction. gcp-oauth.env holds just
    # the OAuth client id/secret, which survive a revoked token and are all
    # setup-rclone-drive.sh needs to re-authorize.
    "config/rclone/rclone.conf:${HOME}/.config/rclone/rclone.conf:600"
    "config/rclone/gcp-oauth.env:${HOME}/.config/rclone/gcp-oauth.env:600"
)

#==================================================#
# Fetch: clone or pull secrets repo
#==================================================#
fetch_secrets() {
    if [[ -d "$SECRETS_DIR/.git" ]]; then
        log_info "Updating secrets repository..."
        if git -C "$SECRETS_DIR" pull --quiet 2>/dev/null; then
            log_success "Secrets updated"
        else
            log_warn "Could not update secrets (offline?)"
        fi
    else
        log_info "Cloning secrets from $SECRETS_REPO ..."
        if git clone --quiet "$SECRETS_REPO" "$SECRETS_DIR" 2>/dev/null; then
            chmod 700 "$SECRETS_DIR"
            log_success "Secrets repository cloned"
        else
            log_warn "Could not clone secrets repository"
            log_info "Create the repo first, then run: bash src/install-secrets.sh --save"
            return 1
        fi
    fi
    return 0
}

#==================================================#
# Install: copy secrets to their destinations
#==================================================#
install_secrets() {
    local installed=0
    for entry in "${SECRET_MAP[@]}"; do
        IFS=':' read -r src dest perms <<< "$entry"
        if [[ "${SECRETS_PROFILE:-full}" == "core" ]]; then
            case "$src" in
                # netrc carries the W&B API key, so it comes with wandb-settings
                git/gitconfig.secret|config/huggingface/token|config/wandb/settings|config/netrc) ;;
                config/rclone/rclone.conf|config/rclone/gcp-oauth.env) ;;
                *) continue ;;
            esac
        fi
        if [[ -f "$SECRETS_DIR/$src" ]]; then
            local dest_dir
            dest_dir="$(dirname "$dest")"
            mkdir -p "$dest_dir"
            # Secret-only directories (~/.ssh, ~/.config/gh, ...) must not be
            # group/world readable; never touch $HOME itself.
            [[ "$dest_dir" != "$HOME" ]] && chmod 700 "$dest_dir"
            cp "$SECRETS_DIR/$src" "$dest"
            chmod "$perms" "$dest"
            log_success "Installed: $dest"
            installed=$((installed + 1))
        fi
    done
    if [[ $installed -eq 0 ]]; then
        log_warn "No secret files found in repository"
    fi
}

#==================================================#
# Save: collect local secrets and push to repo
#==================================================#
save_secrets() {
    # Initialize repo if needed
    if [[ ! -d "$SECRETS_DIR/.git" ]]; then
        log_info "Initializing secrets repository..."
        mkdir -p "$SECRETS_DIR"
        chmod 700 "$SECRETS_DIR"
        git -C "$SECRETS_DIR" init --quiet
        git -C "$SECRETS_DIR" remote add origin "$SECRETS_REPO" 2>/dev/null || true
    fi

    # Collect secret files
    local collected=0
    for entry in "${SECRET_MAP[@]}"; do
        IFS=':' read -r src dest perms <<< "$entry"
        if [[ -f "$dest" ]]; then
            local src_dir
            src_dir="$SECRETS_DIR/$(dirname "$src")"
            mkdir -p "$src_dir"
            chmod 700 "$src_dir"
            cp "$dest" "$SECRETS_DIR/$src"
            chmod "$perms" "$SECRETS_DIR/$src"
            log_success "Collected: $dest -> $src"
            collected=$((collected + 1))
        else
            log_warn "Not found: $dest (skipping)"
        fi
    done

    if [[ $collected -eq 0 ]]; then
        log_warn "No secret files found to save"
        return 1
    fi

    # Commit and push (git -C: never operate on the caller's cwd)
    git -C "$SECRETS_DIR" add -A
    if git -C "$SECRETS_DIR" diff --cached --quiet 2>/dev/null; then
        log_info "No changes to push"
    else
        git -C "$SECRETS_DIR" commit --quiet -m "Update secrets $(date +%Y-%m-%d_%H:%M)"
        if git -C "$SECRETS_DIR" push -u origin main 2>/dev/null || git -C "$SECRETS_DIR" push -u origin master 2>/dev/null; then
            log_success "Secrets pushed to $SECRETS_REPO"
        else
            log_error "Push failed. Make sure the remote repo exists and you have access."
            log_info "Create the private repo first, then retry."
            return 1
        fi
    fi
}

#==================================================#
# Main
#==================================================#
main() {
    case "${1:-}" in
        --core)
            SECRETS_PROFILE=core
            echo '** Installing core secrets (git, Hugging Face, W&B, netrc, rclone)...'
            if fetch_secrets; then
                install_secrets
            fi
            ;;
        --save)
            echo '** Saving secrets to private repository...'
            save_secrets
            ;;
        *)
            echo '** Installing secrets from private repository...'
            if fetch_secrets; then
                install_secrets
            fi
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
