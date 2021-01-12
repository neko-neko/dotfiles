#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

taps=(
  caskroom/cask
)

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
  iterm2
  java
  karabiner-elements
  licecap
  mjml
  mysqlworkbench
  slack
  visual-studio-code
)

brew tap ${taps[@]}
brew install --cask ${casks[@]}
