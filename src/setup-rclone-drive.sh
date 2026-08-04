#!/bin/bash
set -uo pipefail

#==================================================#
# Configure the personal Google Drive remote for rclone
#
# Usage:
#   bash src/setup-rclone-drive.sh                # configure / verify
#   bash src/setup-rclone-drive.sh --token 'JSON' # headless: finish with a
#                                                 # token from another machine
#   bash src/setup-rclone-drive.sh --status       # report only, change nothing
#
# On a machine that already received rclone.conf from the secrets repo this
# is a no-op: install-secrets.sh drops in a working remote directly. The
# interactive path below is only needed on the FIRST machine, or after the
# OAuth token is revoked.
#==================================================#

REMOTE_NAME="${RCLONE_DRIVE_REMOTE:-mydrive}"
RCLONE_DIR="${HOME}/.config/rclone"
RCLONE_CONF="${RCLONE_DIR}/rclone.conf"
OAUTH_ENV="${RCLONE_DIR}/gcp-oauth.env"
DOT_DIR="${MYDOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

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
# Is the remote present and actually usable?
#==================================================#
remote_exists() {
    rclone listremotes 2>/dev/null | grep -qx "${REMOTE_NAME}:"
}

remote_works() {
    rclone about "${REMOTE_NAME}:" >/dev/null 2>&1
}

#==================================================#
# GCP OAuth client credentials
#
# Kept in their own file rather than read back out of rclone.conf: the token
# can be revoked independently, and re-authorizing then only needs these two.
#==================================================#
print_gcp_instructions() {
    cat <<'EOF'

  A Google Cloud OAuth client is required. rclone's built-in one is shared by
  every rclone user and is throttled hard, so use your own:

    1. https://console.cloud.google.com/  ->  create (or pick) a project
    2. APIs & Services -> Library -> enable "Google Drive API"
    3. APIs & Services -> OAuth consent screen
         User type: External
         Add your own Google account under "Test users"
    4. APIs & Services -> Credentials -> Create Credentials
         -> OAuth client ID -> Application type: "Desktop app"
    5. Copy the Client ID and Client secret

EOF
}

load_or_prompt_credentials() {
    if [[ -f "$OAUTH_ENV" ]]; then
        # shellcheck disable=SC1090
        source "$OAUTH_ENV"
    fi

    if [[ -n "${RCLONE_DRIVE_CLIENT_ID:-}" && -n "${RCLONE_DRIVE_CLIENT_SECRET:-}" ]]; then
        log_info "Using GCP OAuth client from $OAUTH_ENV"
        return 0
    fi

    if [[ ! -t 0 ]]; then
        log_error "No credentials at $OAUTH_ENV and stdin is not a terminal"
        log_info "Run this from an interactive shell, or install the secrets first:"
        log_info "  bash $DOT_DIR/src/install-secrets.sh"
        return 1
    fi

    print_gcp_instructions
    read -r -p "  Client ID: " RCLONE_DRIVE_CLIENT_ID
    read -r -s -p "  Client secret: " RCLONE_DRIVE_CLIENT_SECRET
    echo
    if [[ -z "$RCLONE_DRIVE_CLIENT_ID" || -z "$RCLONE_DRIVE_CLIENT_SECRET" ]]; then
        log_error "Both values are required"
        return 1
    fi

    mkdir -p "$RCLONE_DIR"
    chmod 700 "$RCLONE_DIR"
    umask 077
    cat > "$OAUTH_ENV" <<EOF
RCLONE_DRIVE_CLIENT_ID=${RCLONE_DRIVE_CLIENT_ID}
RCLONE_DRIVE_CLIENT_SECRET=${RCLONE_DRIVE_CLIENT_SECRET}
EOF
    chmod 600 "$OAUTH_ENV"
    log_success "Saved credentials to $OAUTH_ENV"
}

#==================================================#
# OAuth token
#==================================================#
has_browser() {
    [[ "$(uname -s)" == "Darwin" ]] && return 0
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]] && return 0
    return 1
}

print_headless_instructions() {
    cat <<EOF

  This machine has no browser, so the OAuth consent screen cannot be opened
  here. On a machine that has one (with rclone installed) run:

    rclone authorize "drive" "${RCLONE_DRIVE_CLIENT_ID}" "<client secret>"

  It prints a JSON blob between "Paste the following into your remote
  machine --->" and "<---End paste". Copy it, then back on this machine:

    bash ${DOT_DIR}/src/setup-rclone-drive.sh --token '<paste the JSON>'

EOF
}

#==================================================#
# Create the remote from client id/secret + token
#
# Every config_* key answers one prompt of rclone's config state machine;
# without them --non-interactive stops early and leaves the remote
# half-written. Verified to end at State "" (i.e. complete).
#==================================================#
create_remote() {
    local token="$1"
    mkdir -p "$RCLONE_DIR"
    chmod 700 "$RCLONE_DIR"

    if ! rclone config create "$REMOTE_NAME" drive \
        client_id="$RCLONE_DRIVE_CLIENT_ID" \
        client_secret="$RCLONE_DRIVE_CLIENT_SECRET" \
        scope=drive \
        token="$token" \
        team_drive= \
        config_refresh_token=false \
        config_change_team_drive=false \
        config_is_local=false \
        --non-interactive >/dev/null 2>&1; then
        log_error "rclone config create failed"
        return 1
    fi
    chmod 600 "$RCLONE_CONF"
    log_success "Remote '${REMOTE_NAME}' written to $RCLONE_CONF"
}

#==================================================#
# Browser path: let rclone run the OAuth flow itself. No --non-interactive,
# so it spins up its local callback server and opens the consent screen.
#==================================================#
create_remote_interactive() {
    mkdir -p "$RCLONE_DIR"
    chmod 700 "$RCLONE_DIR"

    if ! rclone config create "$REMOTE_NAME" drive \
        client_id="$RCLONE_DRIVE_CLIENT_ID" \
        client_secret="$RCLONE_DRIVE_CLIENT_SECRET" \
        scope=drive \
        team_drive= \
        config_is_local=true; then
        log_error "rclone config create failed"
        return 1
    fi
    chmod 600 "$RCLONE_CONF"
    log_success "Remote '${REMOTE_NAME}' written to $RCLONE_CONF"
}

#==================================================#
# Offer to push the new config to the secrets repo
#==================================================#
offer_save() {
    if [[ ! -d "${HOME}/dotfiles-secret/.git" ]]; then
        log_info "No secrets repo at ~/dotfiles-secret; skipping sync"
        return 0
    fi
    if [[ ! -t 0 ]]; then
        log_info "Run 'dotsecret' to sync this config to the secrets repo"
        return 0
    fi
    local reply
    read -r -p "Save rclone config to the secrets repo now? [Y/n] " reply
    case "$reply" in
        [nN]*) log_info "Skipped. Run 'dotsecret' when ready." ;;
        *) bash "$DOT_DIR/src/install-secrets.sh" --save ;;
    esac
}

#==================================================#
# Status report
#==================================================#
show_status() {
    if ! command -v rclone >/dev/null 2>&1; then
        log_error "rclone is not installed"
        return 1
    fi
    log_info "rclone: $(rclone version 2>/dev/null | head -1)"
    if ! remote_exists; then
        log_warn "Remote '${REMOTE_NAME}' is not configured"
        return 1
    fi
    if remote_works; then
        log_success "Remote '${REMOTE_NAME}' is configured and authenticated"
        rclone about "${REMOTE_NAME}:" 2>/dev/null | sed 's/^/    /'
        return 0
    fi
    log_warn "Remote '${REMOTE_NAME}' exists but authentication fails (token revoked or expired?)"
    return 1
}

#==================================================#
# Main
#==================================================#
main() {
    local token=""
    case "${1:-}" in
        --status)
            show_status
            return $?
            ;;
        --token)
            token="${2:-}"
            if [[ -z "$token" ]]; then
                log_error "--token requires the JSON blob from 'rclone authorize'"
                return 1
            fi
            ;;
        "") ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--status | --token 'JSON']" >&2
            return 1
            ;;
    esac

    if ! command -v rclone >/dev/null 2>&1; then
        log_error "rclone is not installed"
        log_info "Install it with: bash $DOT_DIR/src/install.sh"
        return 1
    fi

    # Already working (typically because install-secrets.sh delivered the
    # config from the secrets repo) -- nothing to do.
    if [[ -z "$token" ]] && remote_exists && remote_works; then
        log_success "Remote '${REMOTE_NAME}' already configured and working"
        return 0
    fi

    load_or_prompt_credentials || return 1

    if [[ -n "$token" ]]; then
        create_remote "$token" || return 1
    elif has_browser; then
        log_info "Opening the Google consent screen in your browser..."
        create_remote_interactive || return 1
    else
        print_headless_instructions
        return 1
    fi

    if remote_works; then
        log_success "Google Drive remote '${REMOTE_NAME}' is ready"
        rclone about "${REMOTE_NAME}:" 2>/dev/null | sed 's/^/    /'
    else
        log_error "Remote created but authentication still fails"
        return 1
    fi

    offer_save
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
