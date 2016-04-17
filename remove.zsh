#!/bin/zsh
echo 'remove dotfiles? (y/n)'
read confirmation
if [[ $confirmation = "y" || confirmation = "Y" ]]; then
  rm ${ZDOTDIR:-$HOME}/.aliases
  rm ${ZDOTDIR:-$HOME}/.gemrc
  rm ${ZDOTDIR:-$HOME}/.gitconfig
  rm ${ZDOTDIR:-$HOME}/.hushlogin
  rm ${ZDOTDIR:-$HOME}/.tmux.conf
  rm ${ZDOTDIR:-$HOME}/.vimrc
  rm ${ZDOTDIR:-$HOME}/.vim
  rm ${ZDOTDIR:-$HOME}/.zlogin
  rm ${ZDOTDIR:-$HOME}/.zlogout
  rm ${ZDOTDIR:-$HOME}/.zpreztorc
  rm ${ZDOTDIR:-$HOME}/.zprofile
  rm ${ZDOTDIR:-$HOME}/.zshenv
  rm ${ZDOTDIR:-$HOME}/.zshrc
fi
