#! /bin/bash

# pull latest dotfiles
git pull

# update zsh plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
for plugin_dir in "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
                  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
                  "$ZSH_CUSTOM/plugins/fzf-tab"; do
    if [ -d "$plugin_dir" ]; then
        echo "Updating $(basename $plugin_dir)..."
        git -C "$plugin_dir" pull
    fi
done

# update fzf
if [ -d "$HOME/.fzf" ]; then
    echo "Updating fzf..."
    git -C "$HOME/.fzf" pull && "$HOME/.fzf/install" --all --no-bash --no-fish
fi

# update atuin
if command -v atuin &> /dev/null; then
    echo "Updating atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
fi

# update tmux plugins
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Updating tmux plugins..."
    "$HOME/.tmux/plugins/tpm/bin/update_plugins" all
fi

# reload zsh
exec zsh
