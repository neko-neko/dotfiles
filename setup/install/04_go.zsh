#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install golang and libs...'

libs=(
  github.com/motemen/ghq
  github.com/nsf/gocode
  github.com/davecheney/httpstat
)

brew install go --cross-compile-all
for lib in ${libs[@]}; do
  go get -u -v ${lib}
done

ln -sfv ${GOPATH}/bin/gometalinter.v1 ${GOPATH}/bin/gometalinter
gometalinter --install --update
