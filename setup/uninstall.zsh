#!/bin/zsh
readonly UNINSTALL_TARGETS=(
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
  zshenv
  zshrc
  Library/Preferences/com.googlecode.iterm2.plist
  config/karabiner
  config/nvim
  config/powerline
  'functions'
  git_template
)

echo 'remove dotfiles? (y/N)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  for target in ${UNINSTALL_TARGETS[@]}; do
    unlink ${HOME}/.${target}
  done
fi
