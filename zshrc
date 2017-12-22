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
zplug "sorin-ionescu/prezto"

# ------------------------------
# Read Prezto
# ------------------------------
source ${HOME}/.zprezto/runcoms/zshrc

# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export SHELL=zsh
export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share
PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:${PATH}
MANPATH=/usr/local/opt/coreutils/libexec/gnuman:${MANPATH}
FPATH=${HOME}/.functions:${FPATH}
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
eval "$(rbenv init - zsh)"

# ------------------------------
# node Settings
# ------------------------------
export PATH=${HOME}/.nodebrew/current/bin:${PATH}

# ------------------------------
# Java Settings
# ------------------------------
export JAVA_HOME=$(/usr/libexec/java_home)

# ------------------------------
# GCP Settings
# ------------------------------
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc

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
source ${HOME}/.aliases

# ------------------------------
# define zsh hooks
# ------------------------------
chpwd_hook() { pwd && ls }
add-zsh-hook chpwd chpwd_hook

# ------------------------------
# Auto loads
# ------------------------------
autoload -Uz brew-cask-upgrade
autoload -Uz plantuml
autoload -Uz git-ls-files
autoload -Uz git-checkout
autoload -Uz ssh-list

# ------------------------------
# Key bindings
# ------------------------------

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshrc.local ]]; then
  source ${HOME}/.zshrc.local
fi
