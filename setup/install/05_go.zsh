#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install golang and libs...'

libs=(
  github.com/motemen/ghq
  github.com/golang/protobuf/protoc-gen-go
  github.com/alecthomas/gometalinter
  go get -u golang.org/x/tools/cmd/gopls
)

brew install go
for lib in ${libs[@]}; do
  go get -u -v ${lib}
done
