# ------------------------------
# General Settings
# ------------------------------
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TZ=Asia/Tokyo

export EDITOR=hx
export VISUAL=hx
export PAGER=less
export SHELL=zsh

export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share

setopt no_global_rcs

eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH=/opt/homebrew/opt/curl/bin:${PATH}
export PATH=/opt/homebrew/opt/mysql-client/bin:${PATH}
export PATH=/opt/homebrew/opt/libpq/bin/:${PATH}

# GNU
export PATH=/opt/homebrew/opt/coreutils/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/findutils/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/binutils/bin:${PATH}
export PATH=/opt/homebrew/opt/gnu-sed/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/gnu-indent/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/gnu-tar/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/gnu-which/libexec/gnubin:${PATH}
export PATH=/opt/homebrew/opt/grep/libexec/gnubin:${PATH}

export MANPATH=/opt/homebrew/opt/coreutils/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/findutils/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/binutils/share/man:${MANPATH}
export MANPATH=/opt/homebrew/opt/gnu-sed/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/gnu-indent/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/gnu-tar/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/gnu-which/libexec/gnuman:${MANPATH}
export MANPATH=/opt/homebrew/opt/grep/libexec/gnuman:${PATH}

export FPATH=/opt/homebrew/share/zsh/site-functions:${HOME}/.functions:${FPATH}

# ------------------------------
# History Settings
# ------------------------------
export HISTFILE=${HOME}/.zhistory
export HISTSIZE=1000000
export SAVEHIST=1000000
export LISTMAX=100

# ------------------------------
# mise Settings
# ------------------------------
eval "$(mise activate zsh)"

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
# fzf Settings
# ------------------------------
export FZF_DEFAULT_OPTS='
  --reverse
  --ansi
  --no-info
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
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshenv.local ]]; then
  source ${HOME}/.zshenv.local
fi
