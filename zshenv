# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TZ=Asia/Tokyo

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export SHELL=zsh

export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share

setopt no_global_rcs

export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/opt/openssl/bin:/usr/local/bin:/usr/local/sbin:${PATH}
export MANPATH=/usr/local/opt/coreutils/libexec/gnuman:${MANPATH}
export FPATH=${HOME}/.functions:${FPATH}

# ------------------------------
# History Settings
# ------------------------------
export HISTFILE=${HOME}/.zhistory
export HISTSIZE=1000000
export SAVEHIST=1000000
export LISTMAX=100

# ------------------------------
# anyenv Settings
# ------------------------------
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

# ------------------------------
# golang Settings
# ------------------------------
export GOPATH=${HOME}/go
export PATH=${GOPATH}/bin:${PATH}

# ------------------------------
# Java Settings
# ------------------------------
export JAVA_HOME=$(/usr/libexec/java_home)

# ------------------------------
# Python Settings
# ------------------------------
export PATH="/usr/local/opt/python@3.7/bin:$PATH"

# ------------------------------
# krew Settings
# ------------------------------
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# ------------------------------
# ------------------------------
# Android Settings
# ------------------------------
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

# ------------------------------
# Xcode Settings
# ------------------------------
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# ------------------------------
# fzf Settings
# ------------------------------
export FZF_DEFAULT_OPTS='
  --reverse
  --inline-info
  --ansi
  --multi
  --height 60%
  --color fg:252,bg:233,hl:67,fg+:252,bg+:235,hl+:81
  --color info:144,prompt:161,spinner:135,pointer:135,marker:118
'
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!{.git,node_modules}/*"'

# ------------------------------
# scripts
# ------------------------------
export PATH=${HOME}/.bin:${PATH}

# ------------------------------
# Auto load
# ------------------------------
autoload -Uz add-zsh-hook
autoload fzf-history
zle -N fzf-history

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshenv.local ]]; then
  source ${HOME}/.zshenv.local
fi
