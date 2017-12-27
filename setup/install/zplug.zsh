#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::zplug() {
  util::info 'install zplug plugins...'
  source ${HOME}/.zshrc

  zplug clear
  zplug clean
  zplug update
  zplug install
  source ${HOME}/.zshrc
}
