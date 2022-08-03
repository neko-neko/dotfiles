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
  iterm2
  karabiner-elements
  licecap
  mjml
  mysqlworkbench
  slack
  visual-studio-code
)

brew install --cask ${casks[@]}
