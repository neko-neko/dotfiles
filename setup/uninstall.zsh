#!/bin/zsh
readonly UNINSTALL_TAGETS=(
  aliases
  bin
  ctags
  editorconfig
  gemrc
  gitconfig
  gitignore_global
  gitmessage
  hushlogin
  tern-config
  tigrc
  tmux.conf
  zprezto
  zlogin
  zlogout
  zpreztorc
  zprofile
  zshenv
  zshrc
  Library/Preferences/com.googlecode.iterm2.plist
  config/karabiner
  config/nvim
  'functions'
  git_template
)

echo 'remove dotfiles? (y/N)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  for target in ${UNINSTALL_TAGETS[@]}; do
    unlink ${HOME}/.${target}
  done
fi
