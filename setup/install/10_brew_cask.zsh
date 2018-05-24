#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

taps=(
  caskroom/cask
)

casks=(
  1password
  alfred
  atom
  android-studio
  caffeine
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
  shiftit
  slack
  vagrant
  virtualbox
  zeplin
)

brew tap ${taps[@]}
brew cask install ${casks[@]}
apm install sync-settings
