#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install golang and libs...'

libs=(
  github.com/motemen/ghq
  github.com/mdempsky/gocode
  github.com/golang/protobuf/protoc-gen-go
  github.com/alecthomas/gometalinter
)

brew install go --cross-compile-all
for lib in ${libs[@]}; do
  go get -u -v ${lib}
done

gometalinter --install --update
