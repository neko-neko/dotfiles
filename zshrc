# ------------------------------
# Read Compiled zshrc
# ------------------------------
if [ ! -f ~/.zshrc.zwc -o ~/.zshrc -nt ~/.zshrc.zwc ]; then
  zcompile ~/.zshrc
fi

# ------------------------------
# Read Prezto
# ------------------------------
source "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshrc"

# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export SHELL=zsh
export XDG_CONFIG_HOME=${ZDOTDIR:-$HOME}/.config
export XDG_CACHE_HOME=${ZDOTDIR:-$HOME}/.cache
export XDG_DATA_HOME=${ZDOTDIR:-$HOME}/.local/share
PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:$PATH
MANPATH=/usr/local/opt/coreutils/libexec/gnuman:$MANPATH
FPATH=${ZDOTDIR:-$HOME}/.functions:$FPATH
umask 022

# ------------------------------
# History Settings
# ------------------------------
HISTFILE="${ZDOTDIR:-$HOME}/.zhistory"
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt share_history

# ------------------------------
# golang Settings
# ------------------------------
export GOPATH=$HOME/.go
export PATH=$GOPATH/bin:$PATH

# ------------------------------
# ruby Settings
# ------------------------------
export PATH=$HOME/.rbenv/bin:$PATH
eval "$(rbenv init - zsh)"

# ------------------------------
# node Settings
# ------------------------------
export PATH=$HOME/.nodebrew/current/bin:$PATH

# ------------------------------
# Java Settings
# ------------------------------
export JAVA_HOME=$(/usr/libexec/java_home)

# ------------------------------
# Hub command Settings
# ------------------------------
git() { hub "$@" }

# ------------------------------
# tmuxinator Settings
# ------------------------------
source ~/.tmuxinator/tmuxinator.zsh

# ------------------------------
# Load aliases
# ------------------------------
source "${ZDOTDIR:-$HOME}/.aliases"

# ------------------------------
# define zsh hooks
# ------------------------------
chpwd_hook() { pwd && ls }
add-zsh-hook chpwd chpwd_hook

# ------------------------------
# auto loads
# ------------------------------
autoload brew-cask-upgrade
autoload plantuml

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f "${ZDOTDIR:-$HOME}/.zshrc.local" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshrc.local"
fi
