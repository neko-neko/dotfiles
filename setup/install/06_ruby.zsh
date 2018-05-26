#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Ruby and gems...'

gems=(
  'cocoapods --user-install'
  neovim
  rcodetools
)

rbenv install -s 2.5.1
rbenv global 2.5.1
for gem in ${gems[@]}; do
  gem install ${gem}
done
gem update -f
