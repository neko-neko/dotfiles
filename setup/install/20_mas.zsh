#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install App Store apps...'

apps=(
  # LINE
  539883307
  # Keynote
  409183694
  # WinArchiver
  414855915
)

brew install mas
for app in ${apps[@]}; do
  mas install ${app}
done
