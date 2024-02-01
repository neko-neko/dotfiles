#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install gnu tools...'

formulas=(
  binutils
  coreutils
  findutils
  gnu-indent
  gnu-sed
  gnu-tar
  gnu-which
  grep
  wget
)

for formula in ${formulas[@]}; do
  brew install ${formula}
done
