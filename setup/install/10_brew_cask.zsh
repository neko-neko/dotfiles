#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew cask formulas...'

taps=(
  caskroom/cask
  caskroom/versions
)

casks=(
  1password
  alfred
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
  java8
  karabiner-elements
  licecap
  mysqlworkbench
  nosleep
  shiftit
  slack
  vagrant
  virtualbox
  visual-studio-code
  zeplin
)

brew tap ${taps[@]}
brew cask install ${casks[@]}
