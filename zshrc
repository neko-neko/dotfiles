# ------------------------------
# Read Prezto
# ------------------------------
source "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshrc"

# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export SHELL=zsh
PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:$PATH
MANPATH=/usr/local/opt/coreutils/libexec/gnuman:$MANPATH

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
# brew cask update
# ------------------------------
brew-cask-upgrade() {
  for app in $(brew cask list); do local latest="$(brew cask info "${app}" | awk 'NR==1{print $2}')"; local versions=($(ls -1 "/usr/local/Caskroom/${app}/.metadata/")); local current=$(echo ${versions} | awk '{print $NF}'); if [[ "${latest}" = "latest" ]]; then echo "[!] ${app}: ${current} == ${latest}"; [[ "$1" = "-f" ]] && brew cask install "${app}" --force; continue; elif [[ "${current}" = "${latest}" ]]; then continue; fi; echo "[+] ${app}: ${current} -> ${latest}"; brew cask uninstall "${app}" --force; brew cask install "${app}"; done;
}
