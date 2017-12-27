# ------------------------------
# Read Compiled zshrc
# ------------------------------
if [ ! -f ~/.zshrc.zwc -o ~/.zshrc -nt ~/.zshrc.zwc ]; then
  zcompile ~/.zshrc
fi

# ------------------------------
# Read zplug
# ------------------------------
export ZPLUG_HOME=${HOME}/.zplug
source ${ZPLUG_HOME}/init.zsh

zplug "chrissicool/zsh-256color"
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search"
zplug 'modules/environment', from:prezto
zplug 'modules/terminal', from:prezto
zplug 'modules/editor', from:prezto
zplug 'modules/directory', from:prezto
zplug "modules/prompt", from:prezto

zstyle ':prezto:module:prompt' theme 'steeef'
zstyle ':prezto:module:editor' key-bindings 'emacs'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:terminal:window-title' format '%n@%m: %s'
zstyle ':prezto:module:terminal:tab-title' format '%m: %s'
zstyle ':prezto:module:terminal:multiplexer-title' format '%s'
zstyle ':prezto:module:tmux:iterm' integrate 'yes'

zplug load

# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export SHELL=zsh

autoload -Uz compinit
compinit

export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share

export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:${PATH}
export MANPATH=/usr/local/opt/coreutils/libexec/gnuman:${MANPATH}
export FPATH=${HOME}/.functions:${FPATH}
umask 022

# ------------------------------
# History Settings
# ------------------------------
HISTFILE=${HOME}/.zhistory
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt share_history

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
# GCP Settings
# ------------------------------
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc

# ------------------------------
# fzf Settings
# ------------------------------
export FZF_DEFAULT_OPTS='
  --reverse
  --inline-info
  --ansi
  --border
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
autoload fzf-history
zle -N fzf-history

# ------------------------------
# Key bindings
# ------------------------------
bindkey '^r' fzf-history

# ------------------------------
# Load aliases
# ------------------------------
source ${HOME}/.aliases

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshrc.local ]]; then
  source ${HOME}/.zshrc.local
fi
