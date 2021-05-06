#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install my toys...'

casks=(
  wireshark
)

brew install --cask ${casks[@]}
