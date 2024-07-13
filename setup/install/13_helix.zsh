#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure Helix...'
source ~/.zshenv && source ~/.zshrc

hx --grammar fetch
hx --grammar build
