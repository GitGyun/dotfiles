# .dotfiles

Personal development environment for Linux and macOS. Based on [SeongwoongCho/dotfiles](https://github.com/SeongwoongCho/dotfiles) with custom extensions for ML/DL workflows.

---

## Quick Start

```bash
git clone git@github.com:GitGyun/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash src/install.sh              # full profile (default)
bash src/install.sh standard     # without AI tools
bash src/install.sh minimal      # zsh + nvim + git only
```

### Existing Environment Update

```bash
dotup                            # git pull + relink + plugin updates
dotup-full                       # + system packages
```

### Secrets Management

```bash
# First time: create a private repo at github.com/GitGyun/dotfiles-secret
dotsecret                        # push local secrets to private repo
```

Managed secrets: `~/.gitconfig.secret`, `~/.ssh/config`, `~/.config/glab-cli/config.yml`

---

## Installation Profiles

| Profile | What's Included |
|---------|----------------|
| **minimal** | zsh + oh-my-zsh + zinit + starship + neovim + git + secrets |
| **standard** | minimal + tmux + LSP servers + Codeium AI + plugins |
| **full** | standard + Claude Code + oh-my-claudecode + LSP plugins |

---

## Architecture

```
~/.dotfiles/
  zsh/
    zshrc              -> ~/.zshrc
    zsh.d/
      10-functions.zsh -> ~/.zsh.d/   (utility functions)
      20-aliases.zsh                   (common aliases)
      30-git.zsh                       (git aliases/functions)
  zshenv               -> ~/.zshenv   (unset TMOUT)
  nvim/                -> ~/.config/nvim/
  tmux/
    tmux.conf          -> ~/.tmux.conf
    statusbar.tmux     -> ~/.tmux/statusbar.tmux
  git/
    gitconfig          -> ~/.gitconfig
  config/
    starship.toml      -> ~/.config/starship.toml
    versions.sh        (package version management)
  src/
    install.sh         (main installer)
    install-prerequisite.sh (system packages)
    install-secrets.sh (private repo sync)
    install-omz.sh     (oh-my-zsh)
    update.sh          (updater)
  assets/
    LS_COLORS, Xmodmap, mrtazz_custom.zsh-theme
```

---

## Shell (Zsh)

### Prompt: Starship

Cross-shell prompt configured in `config/starship.toml`:
- Username (always shown, green)
- Directory (cyan, 5-level truncation)
- Git branch (red)
- Conda environment (yellow)
- `CUDA_VISIBLE_DEVICES` (purple, shown when set)
- Command duration (> 5s)
- Hostname (SSH only)

### Plugin Manager: Zinit

| Plugin | Loading | Description |
|--------|---------|-------------|
| **alias-tips** | sync | Shows alias hints when you type a full command |
| **fzf-tab** | sync | Replaces Tab completion with fzf interface |
| **zsh-autosuggestions** | async | Fish-like command suggestions |
| **zsh-syntax-highlighting** | async | Syntax highlighting for commands |

### Key Tools

| Tool | Replaces | Usage |
|------|----------|-------|
| **zoxide** | `cd` | `z <keyword>`, `zi` (interactive) |
| **atuin** | `Ctrl+R` | Smart history search (SQLite, per-directory context) |
| **eza** | `ls` | `ls`, aliased globally |
| **bat** | `cat` | `bat`, aliased as `batcat` |
| **fzf + fd** | `find` | Fuzzy file finding, `fuzzyvim` to open in nvim |
| **duf** | `df` | `df`, aliased globally |

### Features

- **Auto-reload**: zshrc/zsh.d changes are detected and reloaded automatically at each prompt
- **Conda env preservation**: `source ~/.zshrc` preserves your active conda environment
- **Timezone**: Asia/Seoul
- **TMOUT**: Disabled via zshenv (prevents SSH session timeout)

---

## Aliases

### Editor & Terminal

| Alias | Command |
|-------|---------|
| `vim` | `nvim` |
| `tmux` | `tmux -u` (UTF-8 mode) |

### Jupyter

| Alias | Command |
|-------|---------|
| `jl` / `jla` | `jupyter lab` / `jupyter lab --ip 0.0.0.0` |
| `jn` / `jna` | `jupyter notebook` / `jupyter notebook --ip 0.0.0.0` |

### GPU Management

| Alias | Description |
|-------|-------------|
| `ug <ids>` | Set `CUDA_VISIBLE_DEVICES` (e.g., `ug 0,1`) |
| `autoug [n]` | Auto-assign GPU per tmux pane (`$G` shorthand set) |
| `gpu` | Watch gpustat |
| `gpusmi` | Watch nvidia-smi |
| `cudav` | Show CUDA version |

**autoug** assigns GPUs based on tmux pane index:

```bash
# 8 panes, 8 GPUs -> each pane runs autoug
autoug              # pane1->GPU0, pane2->GPU1, ... pane8->GPU7
autoug 2            # pane1->0,1  pane2->2,3  (2 GPUs per pane)

# Use $G as shorthand
python main.py --shard_id $G
```

Works with `prefix + e` (synchronize-panes) -- each pane gets its own GPU.

### Tensorboard & Visdom

| Alias | Usage |
|-------|-------|
| `tsb <port> <logdir>` | Start tensorboard |
| `tsbs <port> <logdir>` | Start tensorboard (no image/scalar sampling) |
| `vis` | Start visdom server |

### Monitoring

| Alias | Description |
|-------|-------------|
| `tblist` | List tensorboard processes |
| `pylist` | List python processes |
| `jnlist` | List jupyter notebooks |

### Git

| Alias | Command |
|-------|---------|
| `ga` | `git add` |
| `gst` | `git status` |
| `gd` | `git diff` |
| `gcm` | `git commit -m` |
| `gps` / `gpl` | `git push` / `git pull` |
| `gclone <user> <repo>` | Clone from GitHub |
| `gra <user> <repo>` | Add remote origin |
| `gitsetup --name <n> --email <e>` | Configure git user |

### Utilities

| Alias/Function | Description |
|----------------|-------------|
| `du` | `du -hd 1` |
| `gdown <id> <name>` | Download from Google Drive |
| `howmany <dir> "<pattern>"` | Count files matching pattern |
| `pyclean` | Remove `__pycache__` files |
| `up <path>` | Set PYTHONPATH (clear with `up`) |
| `fix-dns` | Fix slow DNS with dnsmasq split DNS |
| `dothelp` | Show all aliases, functions, keybindings |

### Dotfiles Management

| Alias | Description |
|-------|-------------|
| `dotup` | Update dotfiles (git + plugins) |
| `dotup-full` | Full update (+ system packages) |
| `dotsecret` | Save secrets to private repo |
| `dotcd` | cd to ~/.dotfiles |

---

## Neovim

Lazy.nvim plugin manager with full LSP, AI completion, and modern editing.

### Colorscheme

**OceanicNext** (default). **Sonokai** (andromeda) available as alternative -- edit `nvim/lua/plugins/sonokai.lua` to enable.

### Plugins

| Plugin | Purpose |
|--------|---------|
| **telescope** | Fuzzy finder (`Ctrl+P` files, `Ctrl+O` grep) |
| **nvim-cmp** | Autocompletion (LSP + Codeium AI + snippets) |
| **treesitter** | Syntax highlighting |
| **mason + mason-lspconfig** | LSP auto-installer (clangd, pylsp, jedi, lua_ls, bashls) |
| **conform.nvim** | Format on save (black, shfmt, clang-format, stylua) |
| **gitsigns** | Git diff in gutter + inline blame |
| **nvim-tree** | File explorer (`"` to toggle) |
| **barbar** | Buffer tabs (bubblegum theme) |
| **codeium** | AI code completion |
| **auto-session** | Automatic session save/restore |
| **snacks.nvim** | Dashboard, indent guides, notifications |
| **yanky** | Yank history (`<leader>p`) |
| **markview** | Markdown preview |

### Keybindings (Leader: `,`)

| Key | Action |
|-----|--------|
| `,s` | Save file |
| `,R` | Reload config |
| `@` | Clear search highlight |
| `Ctrl+P` | Find files (Telescope) |
| `Ctrl+O` | Live grep (Telescope) |
| `[b` / `]b` | Previous/Next buffer |
| `,d` | Go to definition |
| `,g` | Go back |
| `,b` / `,v` | Insert ipdb breakpoint above/below |
| `,p` | Yank history |
| `"` | Toggle file explorer |
| `F2` | LSP rename |
| `F4` | Code action |
| `F8` | Toggle paste mode |
| `F9` | Toggle line numbers + indent guides |
| `y` / `yy` | Yank to system clipboard (OSC52) |

---

## Tmux

Prefix: `Ctrl+A`

### Dynamic Statusbar

Real-time CPU, RAM, and GPU usage with color gradients:
- **CPU** (red shades): idle to 80%+ heat
- **RAM** (orange shades): low to 90%+ warning
- **GPU** (green shades): idle to 90%+ full load
- Date/time on the right

### Key Bindings

| Key | Action |
|-----|--------|
| `v` | Vertical split |
| `s` | Horizontal split |
| `h/j/k/l` | Navigate panes |
| `Ctrl+h/j/k/l` | Navigate (vim-aware) |
| `c` | New window |
| `0-9` | Select window |
| `e` | Toggle sync mode (with color change) |
| `r` | Reload config |
| `> / <` | Resize pane width |
| `+ / -` | Resize pane height |
| `Esc` / `Enter` | Enter copy mode |
| `A` | Rename window |

### Plugins (TPM)

| Plugin | Key | Description |
|--------|-----|-------------|
| **tmux-resurrect** | | Session save/restore across reboots |
| **tmux-continuum** | | Auto-save sessions |
| **extrakto** | `prefix+Tab` | Extract text from pane |
| **tmux-thumbs** | `prefix+F` | Vimium-style text copy from screen |
| **tmux-fzf** | `prefix+Ctrl+F` | fzf search for sessions/windows/panes |
| **tmux-sessionx** | `prefix+o` | Session manager (create/switch/delete) |
| **prefix-highlight** | | Shows when prefix is active |

---

## Git

### Delta (diff pager)

Side-by-side diffs with `forest-night` theme (gruvbox-dark syntax). Enabled globally via gitconfig.

### Aliases

| Alias | Command |
|-------|---------|
| `co` | `checkout` |
| `cob` | `checkout -b` |
| `undo` | `reset --soft HEAD^` |
| `cm` | `commit -m` |

### Secrets

Credentials stored in `~/.gitconfig.secret` (included via `[include]`), managed by `dotsecret` command.

---

## Cross-Platform Support

| Feature | Linux | macOS |
|---------|-------|-------|
| Package install | apt + cargo + scripts | Homebrew |
| Xmodmap | Symlinked | Skipped |
| DNS fix | dnsmasq split DNS | Skipped |
| locale-gen | Runs | Skipped |
| Nerd Fonts | Manual install | `brew install font-fira-code-nerd-font` |
| tmux statusbar | CPU/RAM/GPU | CPU/RAM (no nvidia-smi) |

---

## Quick Reference

Run `dothelp` in your terminal for a categorized reference of all aliases, functions, keybindings, and plugins.

```bash
dothelp              # show everything
dothelp alias        # aliases only
dothelp func         # functions only
dothelp key          # keybindings only
dothelp accel        # GPU commands
dothelp vim          # neovim keys
dothelp tmux         # tmux keys
dothelp plugin       # plugin list
```
