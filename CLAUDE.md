# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles for Linux/macOS dev environments, focused on ML/DL workflows with GPU management. Manages zsh, neovim, tmux, git, and system package installation across three profiles: minimal, standard, and full.

## Key Commands

```bash
# Install
bash src/install.sh              # full profile (default)
bash src/install.sh standard     # without AI tools
bash src/install.sh minimal      # zsh + nvim + git only

# Update (what `dotup` and `dotup-full` aliases run)
bash src/update.sh               # git pull + relink + plugin sync
bash src/update.sh --packages    # also update system packages

# Secrets
bash src/install-secrets.sh          # fetch secrets from private repo
bash src/install-secrets.sh --save   # push local secrets to private repo

# Cleanup
bash src/cleanse.sh              # remove all symlinks and installed components
```

## Pre-commit Hooks

shfmt (indent=2, CI mode) and StyLua run on commit. Shell scripts use 2-space indentation.

## Architecture

- **`src/install.sh`** - Main entry point. Profiles are cumulative: `install_minimal` -> `install_standard` -> `install_full`. Creates symlinks from this repo into `$HOME`.
- **`src/install-prerequisite.sh`** - System package installer with helpers (`install_by_apt`, `install_by_cargo`, `install_by_uv`, `install_by_script`). Detects Linux vs macOS and uses apt/cargo/uv or Homebrew accordingly. Includes DNS optimization with dnsmasq split DNS.
- **`src/install-secrets.sh`** - Syncs secrets (gitconfig.secret, SSH config, gh/glab tokens, atuin key, HuggingFace token, wandb, netrc) with a private git repo. Secret mapping defined in `SECRET_MAP` array.
- **`src/update.sh`** - Updater: pulls git, relinks symlinks, syncs neovim/tmux/zplug plugins. Stashes local changes before pull.
- **`config/versions.sh`** - Central version pinning. Loads environment-specific overrides from `config/versions.d/{distro}-{version}.sh`. Local overrides go in `config/versions.d/local.sh` (gitignored).

## Symlink Layout

Config files in this repo are symlinked into `$HOME`:
- `zsh/zshrc` -> `~/.zshrc`, `zsh/zsh.d/` -> `~/.zsh.d/`
- `nvim/` -> `~/.config/nvim/`
- `tmux/tmux.conf` -> `~/.tmux.conf`
- `git/gitconfig` -> `~/.gitconfig`
- `config/starship.toml` -> `~/.config/starship.toml`

## Shell Config Loading Order

Zsh sources files from `zsh/zsh.d/` in numeric order: `10-functions.zsh` (utility functions), `20-aliases.zsh` (aliases), `30-git.zsh` (git aliases/functions). The zshrc auto-reloads when these files change.

## Adding Secrets

Add entries to the `SECRET_MAP` array in `src/install-secrets.sh` using format `"path_in_repo:destination:permissions"`.

## Adding System Packages

Add to the appropriate section in `src/install-prerequisite.sh`: `apt_packages` array for apt, or use the helper functions (`install_by_cargo`, `install_by_uv`, `install_by_script`) for other sources.
