#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

npms=(
  flow-bin
  neovim
  react-native-cli
)

ndenv install v12.0.0
ndenv global v12.0.0

if which yarn > /dev/null; then
  brew upgrade yarn --without-node
else
  brew install yarn --without-node
fi

for npm in ${npms[@]}; do
  npm install -g ${npm}
done
