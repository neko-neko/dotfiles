#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

casks=(
  1password-cli
  android-studio
  caffeine
  cursor
  claude
  cyberduck
  dbeaver-community
  docker
  discord
  firefox
  google-cloud-sdk
  google-chrome
  karabiner-elements
  licecap
  notion
  notion-calendar
  raycast
  slack
  wez/wezterm/wezterm
)

brew install --cask ${casks[@]}

# font
brew tap homebrew/cask-fonts
brew install font-hack-nerd-font
brew install font-monaspace
