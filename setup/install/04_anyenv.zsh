#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install anyenv...'

if [[ ! -e ${HOME}/.anyenv ]]; then
  git clone https://github.com/riywo/anyenv ${HOME}/.anyenv
  source ${HOME}/.zshenv

  # install anyenv plugins
  anyenv install --init
  mkdir -p $(anyenv root)/plugins
  git clone https://github.com/znz/anyenv-update.git $(anyenv root)/plugins/anyenv-update
  git clone https://github.com/znz/anyenv-git.git $(anyenv root)/plugins/anyenv-git

  # install *env
  anyenv install rbenv
  anyenv install nodenv
fi
anyenv update
anyenv git pull
source ${HOME}/.zshenv
