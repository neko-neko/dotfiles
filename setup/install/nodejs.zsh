#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::nodejs() {
  util::info 'install Node.js...'

  curl -L git.io/nodebrew | perl - setup
  mkdir -p ${HOME}/.nodebrew/src
  nodebrew install-binary v8.9.3
  nodebrew use v8.9.3

  brew install yarn --without-node
}
