#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

npms=(
  neovim
)

ndenv install v9.11.1
ndenv global v9.11.1

if which yarn > /dev/null; then
  brew upgrade yarn
else
  brew install yarn --without-node
fi

for npm in ${npms[@]}; do
  npm install -g ${npm}
done
