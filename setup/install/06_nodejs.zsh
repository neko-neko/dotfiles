#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

npms=(
  neovim
)

nodenv install 8.10.0
nodenv global 8.10.0
brew install yarn --without-node
for npm in ${npms[@]}; do
  npm install -g ${npm}
done
npm update -g
