#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install Node.js...'

curl -L git.io/nodebrew | perl - setup
mkdir -p ${HOME}/.nodebrew/src
nodebrew install-binary v8.9.4
nodebrew use v8.9.4

brew install yarn --without-node
