#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Ruby and gems...'

gems=(
  neovim
  rcodetools
)

brew install ruby-build
brew install rbenv
rbenv rehash
rbenv install -s 2.4.3
rbenv global 2.4.3
for gem in ${gems[@]}; do
  gem install ${gem}
done
gem update
