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

# GPU/NPU/HPU monitoring
alias ug='usegpu'
alias gpu="watch --color -n.5 gpustat --color"
alias gpusmi="watch -n.5 nvidia-smi"
alias npu="watch --color -n.5 npustat --color"
alias uh='usehpu'
alias hpusmi="watch -n.5 hl-smi"

# CUDA version info
alias cudav='nvcc --version'
alias cudnnv='cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2'

# Google Drive download
function gdown(){
    CONFIRM=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$1" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$1" -O $2
    rm -rf /tmp/cookies.txt
}

# CMake presets (Mobilint)
alias cmakeauto='cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold" -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"'
alias cmakeauto_r='cmake .. -DPRODUCT=regulus-v4 -DDRIVER_TYPE=regulus -DVENDOR=mobilint -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold" -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"'
alias cmo='cmakeauto'
alias cmo_r='cmakeauto_r'

# Dotfiles management
alias dotup='bash $MYDOTFILES/src/update.sh'
alias dotup-full='bash $MYDOTFILES/src/update.sh --full'
alias dotsecret='bash $MYDOTFILES/src/install-secrets.sh --save'
alias dotcd='cd $MYDOTFILES'

