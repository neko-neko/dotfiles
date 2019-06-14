#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  bungcip.better-toml
  castwide.solargraph
  CoenraadS.bracket-pair-colorizer-2
  dbaeumer.vscode-eslint
  eamodio.gitlens
  EditorConfig.EditorConfig
  esbenp.prettier-vscode
  GitHub.vscode-pull-request-github
  kumar-harsh.graphql-for-vscode
  mauve.terraform
  ms-kubernetes-tools.vscode-kubernetes-tools
  ms-python.python
  ms-vscode-remote.remote-containers
  ms-vscode.Go
  ms-vsliveshare.vsliveshare
  nonylene.dark-molokai-theme
  PeterJausovec.vscode-docker
  rebornix.ruby
  redhat.vscode-yaml
  shardulm94.trailing-spaces
  VisualStudioExptTeam.vscodeintellicode
  vscode-icons-team.vscode-icons
  yzhang.markdown-all-in-one
  zxh404.vscode-proto3
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
