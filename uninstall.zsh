#!/bin/zsh
echo 'remove dotfiles? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  unlink ${ZDOTDIR:-$HOME}/.aliases
  unlink ${ZDOTDIR:-$HOME}/.editorconfig
  unlink ${ZDOTDIR:-$HOME}/.functions
  unlink ${ZDOTDIR:-$HOME}/.gemrc
  unlink ${ZDOTDIR:-$HOME}/.gitconfig
  unlink ${ZDOTDIR:-$HOME}/.git_template
  unlink ${ZDOTDIR:-$HOME}/.hushlogin
  unlink ${ZDOTDIR:-$HOME}/.tmux.conf
  unlink ${ZDOTDIR:-$HOME}/.tmuxinator
  unlink ${ZDOTDIR:-$HOME}/.zprezto
  unlink ${ZDOTDIR:-$HOME}/.zlogin
  unlink ${ZDOTDIR:-$HOME}/.zlogout
  unlink ${ZDOTDIR:-$HOME}/.zpreztorc
  unlink ${ZDOTDIR:-$HOME}/.zprofile
  unlink ${ZDOTDIR:-$HOME}/.zshenv
  unlink ${ZDOTDIR:-$HOME}/.zshrc
fi
