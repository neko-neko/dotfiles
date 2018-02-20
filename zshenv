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

export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:${PATH}
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
# golang Settings
# ------------------------------
export GOPATH=${HOME}/.go
export PATH=${GOPATH}/bin:${PATH}

# ------------------------------
# ruby Settings
# ------------------------------
export PATH=${HOME}/.rbenv/bin:${PATH}
eval "$(rbenv init - --no-rehash)"

# ------------------------------
# node Settings
# ------------------------------
export PATH=${HOME}/.nodebrew/current/bin:${PATH}

# ------------------------------
# Java Settings
# ------------------------------
export JAVA_HOME=$(/usr/libexec/java_home)

# ------------------------------
# Lua Settings
# ------------------------------
eval $(luarocks path --bin)

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

# ------------------------------
# scripts
# ------------------------------
export PATH=${HOME}/.bin:${PATH}

# ------------------------------
# Auto load
# ------------------------------
autoload -Uz add-zsh-hook
autoload -Uz compinit && compinit -u
autoload fzf-history
zle -N fzf-history

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshenv.local ]]; then
  source ${HOME}/.zshenv.local
fi
