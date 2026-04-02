# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo for a Linux-based ML/deep learning development environment. Configures zsh (oh-my-zsh + spaceship theme), vim, tmux, git, conda, and JupyterLab. Forked originally from https://github.com/1Konny/dotfiles.

## Key Commands

- **Full install**: `cd ~/dotfiles && bash install.sh` — symlinks all configs, installs oh-my-zsh, zsh plugins, vim plugins, and JupyterLab settings
- **Force install** (skip backups): `bash install.sh -f`
- **Update**: `bash update.sh` — pulls latest and reloads zsh
- **Clean uninstall**: `bash cleanse.sh` — removes all symlinked configs and installed tools

## Architecture

The install script (`install.sh`) works by symlinking dotfiles from this repo into `$HOME`:
- `zshrc` → `~/.zshrc` (sources aliases from `~/.aliases/*` and `LS_COLORS`)
- `vimrc` → `~/.vimrc`
- `tmux.conf` → `~/.tmux.conf`
- `gitconfig` → `~/.gitconfig` (user-specific secrets go in `~/.gitconfig.secret`, not tracked)
- `condarc` → `~/.condarc`
- `Xmodmap` → `~/.Xmodmap`
- `aliases/` → `~/.aliases/` (directory symlink, contains `git`, `misc`, `conda` alias files)

The `fixes/` directory contains patched versions of third-party files (spaceship theme's `section.zsh`, custom `cuda.zsh` section, and sonokai vim colorscheme).

The `aliases/misc` file defines the `buo` (backup-original) function used by `install.sh` to back up existing dotfiles to `~/dotfiles_backup/` before overwriting.

## Conventions

- Git credentials are stored in `~/.gitconfig.secret` (not in this repo). The tracked `gitconfig` includes it via `[include]`.
- Timezone is set to `Asia/Seoul` in zshrc.
- Aliases are split by domain: `aliases/git`, `aliases/misc` (GPU/tensorboard/jupyter utilities), `aliases/conda`.
