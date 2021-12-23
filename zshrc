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

zplug 'zplug/zplug', hook-build:'zplug --self-manage'
zplug 'chrissicool/zsh-256color'
zplug 'seebi/dircolors-solarized'

zplug 'zsh-users/zsh-autosuggestions'
zplug 'zsh-users/zsh-completions'
zplug 'zdharma-continuum/fast-syntax-highlighting', defer:2

zplug 'rimraf/k'
zplug 'soimort/translate-shell', \
    at:stable, as:command, use:"build/*", \
    hook-build:"make build &> /dev/null"

zplug 'plugins/extract', from:oh-my-zsh
zplug 'modules/terminal', from:prezto
zplug 'modules/editor', from:prezto
zplug 'modules/directory', from:prezto
zplug "${HOME}/.dotfiles/theme", \
  from:local, \
  as:theme
zplug 't413/zsh-background-notify'
zplug 'supercrabtree/k'

# prezto
zstyle ':prezto:module:editor' key-bindings 'emacs'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:terminal:window-title' format '%n@%m: %s'
zstyle ':prezto:module:terminal:tab-title' format '%m: %s'
zstyle ':prezto:module:terminal:multiplexer-title' format '%s'

zplug load

# ------------------------------
# ztyle
# ------------------------------
# color
eval $(dircolors ${ZPLUG_HOME}/repos/seebi/dircolors-solarized/dircolors.ansi-dark)
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# completion
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ------------------------------
# General Settings
# ------------------------------
# umask
umask 022

# prompt
setopt transient_rprompt

# disable Beep
setopt no_beep
setopt no_list_beep
setopt no_hist_beep

# completion
setopt auto_list
setopt auto_menu
setopt auto_param_keys
setopt auto_param_slash
setopt list_types
setopt list_packed
setopt mark_dirs
setopt complete_in_word
setopt always_last_prompt
setopt print_eight_bit

# history
setopt hist_ignore_dups
setopt hist_no_store
setopt hist_ignore_space
setopt share_history
setopt extended_history
setopt inc_append_history

export LESS='-R'
export LESSOPEN="|/usr/local/bin/src-hilite-lesspipe.sh %s"

# ------------------------------
# pip Settings
# ------------------------------
eval "$(pip3 completion --zsh)"

# ------------------------------
# GCP Settings
# ------------------------------
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc
source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc

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
if [[ -f ${HOME}/.aliases.local ]]; then
  source ${HOME}/.aliases.local
fi
