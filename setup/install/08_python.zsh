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
  yapf
)

brew install python@2
brew install python3
pip3 install --upgrade pip setuptools wheel
for pip in ${pips[@]}; do
  pip3 install --user ${pip}
done
