#!/bin/zsh
echo 'remove dotfiles? (y/n)'
read confirmation
if [[ $confirmation = "y" || confirmation = "Y" ]]; then
  unlink ${ZDOTDIR:-$HOME}/.aliases
  unlink ${ZDOTDIR:-$HOME}/.gemrc
  unlink ${ZDOTDIR:-$HOME}/.gitconfig
  unlink ${ZDOTDIR:-$HOME}/.hushlogin
  unlink ${ZDOTDIR:-$HOME}/.tmux.conf
  unlink ${ZDOTDIR:-$HOME}/.vimrc
  unlink ${ZDOTDIR:-$HOME}/.vim
  unlink ${ZDOTDIR:-$HOME}/.zlogin
  unlink ${ZDOTDIR:-$HOME}/.zlogout
  unlink ${ZDOTDIR:-$HOME}/.zprezto
  unlink ${ZDOTDIR:-$HOME}/.zpreztorc
  unlink ${ZDOTDIR:-$HOME}/.zprofile
  unlink ${ZDOTDIR:-$HOME}/.zshenv
  unlink ${ZDOTDIR:-$HOME}/.zshrc
fi
