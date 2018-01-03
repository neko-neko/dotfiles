#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install zplug plugins...'
source ${HOME}/.zshrc

zplug clear
zplug clean
zplug update
zplug install
source ${HOME}/.zshrc
