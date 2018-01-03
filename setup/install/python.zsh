#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::python() {
  util::info 'install Python...'

  local pips=(
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
}
