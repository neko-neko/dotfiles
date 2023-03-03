#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

casks=(
  adoptopenjdk
  1password
  alfred
  android-studio
  cyberduck
  dbeaver-community
  docker
  discord
  firefox
  google-cloud-sdk
  google-chrome
  google-japanese-ime
  kindle
  karabiner-elements
  licecap
  mjml
  mysqlworkbench
  slack
  visual-studio-code
  wez/wezterm/wezterm
)

brew install --cask ${casks[@]}
