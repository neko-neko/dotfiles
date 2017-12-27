#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::gnu() {
  util::info 'install gnu tools...'

  local formulas=(
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
    brew install ${formula} --with-default-names
  done
}
