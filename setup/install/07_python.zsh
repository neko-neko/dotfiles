#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Python...'

pips=(
  awscli
  csvkit
  neovim
  powerline-status
  psutil
)

brew install python3
pip3 install --upgrade pip setuptools wheel
for pip in ${pips[@]}; do
  pip3 install ${pip}
done
