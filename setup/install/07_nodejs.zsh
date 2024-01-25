#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

npms=(
  neovim
  typescript
)

nodenv init
nodenv install 20.9.0
nodenv global 20.9.0

if which yarn > /dev/null; then
  brew upgrade yarn
else
  brew install yarn
fi

for npm in ${npms[@]}; do
  npm install -g ${npm}
done
