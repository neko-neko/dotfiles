#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Ruby and gems...'

gems=(
  bundler
  neovim
)

rbenv install 3.2.2
rbenv global 3.2.2
for gem in ${gems[@]}; do
  gem install ${gem}
done
gem update -f
