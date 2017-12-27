#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::ruby() {
  util::info 'install Ruby and gems...'

  local gems=(
    neovim
    rcodetools
  )

  brew install ruby-build
  brew install rbenv
  rbenv rehash
  rbenv install -s 2.4.3
  rbenv global 2.4.3
  for gem in ${gems[@]}; do
    gem install ${gem}
  done
}
