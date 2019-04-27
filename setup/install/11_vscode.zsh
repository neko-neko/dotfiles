#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  castwide.solargraph
  dbaeumer.vscode-eslint
  esbenp.prettier-vscode
  kumar-harsh.graphql-for-vscode
  mauve.terraform
  ms-kubernetes-tools.vscode-kubernetes-tools
  ms-python.python
  ms-vscode.Go
  nonylene.dark-molokai-theme
  PeterJausovec.vscode-docker
  rebornix.ruby
  redhat.vscode-yaml
  shardulm94.trailing-spaces
  vscode-icons-team.vscode-icons
  vsmobile.vscode-react-native
  yzhang.markdown-all-in-one
  zxh404.vscode-proto3
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
