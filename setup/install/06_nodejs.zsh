#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

npms=(
  neovim
)
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
nvm install v8.10.0

brew install yarn --without-node
for npm in ${npms[@]}; do
  npm install -g ${npm}
done
npm update -g
