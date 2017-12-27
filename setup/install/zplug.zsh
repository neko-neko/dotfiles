#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::zplug() {
  util::info 'install zplug plugins...'
  source ${HOME}/.zshrc
  zplug install

  # install prezto
  echo 'install prezto...'
  if [[ -e ${HOME}/.zprezto ]]; then
    unlink ${HOME}/.zprezto
  fi
  ln -sfv ${HOME}/.zplug/repos/sorin-ionescu/prezto ${HOME}/.zprezto
  source ${HOME}/.zshrc
}
