#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Python...'

pips=(
  awscli
  csvkit
  grpcio-tools
  googleapis-common-protos
  pynvim
)

brew install python3
pip3 install --upgrade pip setuptools wheel
for pip in ${pips[@]}; do
  pip3 install --user ${pip}
done
