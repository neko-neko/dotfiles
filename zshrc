# ------------------------------
# Read Compiled zshrc
# ------------------------------
if [ ! -f ~/.zshrc.zwc -o ~/.zshrc -nt ~/.zshrc.zwc ]; then
  zcompile ~/.zshrc
fi

# ------------------------------
# sheldon
# ------------------------------
eval "$(sheldon source)"

# ------------------------------
# ztyle
# ------------------------------
# prezto
zstyle ':prezto:module:editor' key-bindings 'emacs'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:terminal:window-title' format '%n@%m: %s'
zstyle ':prezto:module:terminal:tab-title' format '%m: %s'
zstyle ':prezto:module:terminal:multiplexer-title' format '%s'

# color
eval $(dircolors ${XDG_DATA_HOME}/sheldon/repos/github.com/seebi/dircolors-solarized/dircolors.ansi-dark)
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
source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc
source /opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

# ------------------------------
# Key bindings
# ------------------------------
bindkey '^r' fzf-history

# ------------------------------
# Load aliases
# ------------------------------
source ${HOME}/.aliases

# ------------------------------
# Starship Theme
# ------------------------------
eval "$(starship init zsh)"

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshrc.local ]]; then
  source ${HOME}/.zshrc.local
fi

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f /Users/nishikataseiichi/.config/.dart-cli-completion/zsh-config.zsh ]] && . /Users/nishikataseiichi/.config/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]

