#!/bin/zsh
readonly UNINSTALL_TARGETS=(
  aliases
  bin
  'ctags.d'
  editorconfig
  gemrc
  gitconfig
  gitignore_global
  git_template
  gitmessage
  hushlogin
  tigrc
  tmux.conf
  zshenv
  zshrc
  Library/Preferences/com.googlecode.iterm2.plist
  config/karabiner
  config/nvim
  'functions'
)

echo 'remove dotfiles? (y/N)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  for target in ${UNINSTALL_TARGETS[@]}; do
    unlink ${HOME}/.${target}
  done
fi
