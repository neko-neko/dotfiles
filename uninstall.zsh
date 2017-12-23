#!/bin/zsh
echo 'remove dotfiles? (y/n)'
read confirmation
if [[ $confirmation = "y" || $confirmation = "Y" ]]; then
  unlink ${HOME}/.aliases
  unlink ${HOME}/.ctags
  unlink ${HOME}/.editorconfig
  unlink ${HOME}/.functions
  unlink ${HOME}/.gemrc
  unlink ${HOME}/.gitconfig
  unlink ${HOME}/.gitignore_global
  unlink ${HOME}/.git_template
  unlink ${HOME}/.hushlogin
  unlink ${HOME}/.tmux.conf
  unlink ${HOME}/.tmuxinator
  unlink ${HOME}/.tigrc
  unlink ${HOME}/.zprezto
  unlink ${HOME}/.zlogin
  unlink ${HOME}/.zlogout
  unlink ${HOME}/.zpreztorc
  unlink ${HOME}/.zprofile
  unlink ${HOME}/.zshenv
  unlink ${HOME}/.zshrc
  unlink ${HOME}/.config/nvim
fi
