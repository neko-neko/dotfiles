#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install App Store apps...'
source ~/.zshenv && source ~/.zshrc

apps=(
  # LINE
  539883307
  # Keynote
  409183694
  # WinArchiver
  414855915
)

if ! util::is_ci; then
  brew install mas
  for app in ${apps[@]}; do
    mas install "${app}"
  done
fi
