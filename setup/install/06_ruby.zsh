#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Ruby and gems...'

gems=(
  bundler
  neovim
)

rbenv install -s 2.7.3
rbenv global 2.7.3
for gem in ${gems[@]}; do
  gem install ${gem}
done
gem update -f
