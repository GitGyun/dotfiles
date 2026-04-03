#!/bin/zsh
# Common aliases

# Editor
alias vim='nvim'
alias vimconflicts='vim $(git diff --name-only --diff-filter=U)'

# Terminal multiplexer
alias tmux='tmux -u'

# Jupyter
alias jn='jupyter notebook'
alias jna='jupyter notebook --ip 0.0.0.0'
alias jl='jupyter lab'
alias jla='jupyter lab --ip 0.0.0.0 --allow-root'

# Modern CLI replacements
alias ls='eza'
alias df='duf'
alias bat='batcat'
if [[ $- == *i* ]]; then
    alias cd='z'
fi

# Utilities
alias du='du -hd 1'
alias cpr='colorprint'

# Tensorboard
function tsbwrapper(){
    tensorboard --bind_all --port $1  --logdir $2
}
function tsbswrapper(){
    tensorboard --bind_all --port $1  --logdir $2 --samples_per_plugin images=0,scalars=0
}
alias tsb='tsbwrapper'
alias tsbs='tsbswrapper'

# Visdom
alias vis='python -m visdom.server'

# Process listing
alias jnlist='jupyter notebook list'
alias tblist='ps -ef | grep "tensorboard"'
alias pylist='ps -ef | grep "python"'

# Claude Code (auto-update OMC before launch)
alias claude='omc update && IS_SANDBOX=1 command claude --dangerously-skip-permissions'

# GPU monitoring
alias ug='usegpu'
alias gpu="watch --color -n.5 gpustat --color"
alias gpusmi="watch -n.5 nvidia-smi"

# CUDA version info
alias cudav='nvcc --version'
alias cudnnv='cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2'

# Google Drive download
function gdown(){
    CONFIRM=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$1" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$1" -O $2
    rm -rf /tmp/cookies.txt
}

# Dotfiles management
alias dotup='bash $MYDOTFILES/src/update.sh'
alias dotup-full='bash $MYDOTFILES/src/update.sh --full'
alias dotsecret='bash $MYDOTFILES/src/install-secrets.sh --save'
alias dotcd='cd $MYDOTFILES'

