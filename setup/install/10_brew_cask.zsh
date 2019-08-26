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
  caffeine
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
  mysqlworkbench
  nosleep
  slack
  vagrant
  virtualbox
  visual-studio-code
  zeplin
)

brew tap ${taps[@]}
brew cask install ${casks[@]}
