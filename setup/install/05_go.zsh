#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install golang and libs...'

libs=(
  github.com/motemen/ghq
  github.com/golang/protobuf/protoc-gen-go
  github.com/alecthomas/gometalinter
  github.com/saibing/bingo
)

brew install go
for lib in ${libs[@]}; do
  go get -u -v ${lib}
done

gometalinter --install --update
