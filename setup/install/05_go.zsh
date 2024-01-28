#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install golang and libs...'

libs=(
  github.com/motemen/ghq
)

brew install go
for lib in ${libs[@]}; do
  go get -u -v ${lib}
done
