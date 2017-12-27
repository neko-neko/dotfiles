#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::gnu() {
  info 'install gnu tools...'

  brew install coreutils --with-default-names
  brew install findutils --with-default-names
  brew install gnu-indent --with-default-names
  brew install gnu-sed --with-default-names
  brew install gnu-tar --with-default-names
  brew install gnu-which --with-default-names
  brew install grep --with-default-names
  brew install wget --with-iri --with-default-names
}
