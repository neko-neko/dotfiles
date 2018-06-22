#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Python...'

pips=(
  awscli
  csvkit
  flake8
  grpcio-tools
  googleapis-common-protos
  neovim
  psutil
  yapf
)

brew install python
brew install python3
pip3 install --upgrade pip setuptools wheel
for pip in ${pips[@]}; do
  pip3 install ${pip}
done
pip3 list --outdated --format=legacy | awk '{print $1}' | xargs pip3 install -U
