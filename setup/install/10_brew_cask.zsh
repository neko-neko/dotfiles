#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

casks=(
  alfred
  android-studio
  cyberduck
  dbeaver-community
  docker
  discord
  firefox
  google-cloud-sdk
  google-chrome
  karabiner-elements
  licecap
  slack
  visual-studio-code
  wez/wezterm/wezterm
)

brew install --cask ${casks[@]}
