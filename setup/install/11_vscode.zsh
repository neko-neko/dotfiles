#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  alefragnani.project-manager
  apollographql.vscode-apollo
  bungcip.better-toml
  castwide.solargraph
  CoenraadS.bracket-pair-colorizer-2
  DavidAnson.vscode-markdownlint
  dbaeumer.vscode-eslint
  eamodio.gitlens
  EditorConfig.EditorConfig
  esbenp.prettier-vscode
  foxundermoon.shell-format
  GitHub.vscode-pull-request-github
  golang.go
  GraphQL.vscode-graphql
  Gruntfuggly.todo-tree
  hashicorp.terraform
  ionutvmi.path-autocomplete
  kumar-harsh.graphql-for-vscode
  ms-azuretools.vscode-docker
  ms-python.python
  ms-python.vscode-pylance
  ms-toolsai.jupyter
  ms-vscode-remote.remote-containers
  ms-vsliveshare.vsliveshare
  nonylene.dark-molokai-theme
  rebornix.ruby
  shardulm94.trailing-spaces
  streetsidesoftware.code-spell-checker
  stylelint.vscode-stylelint
  Tim-Koehler.helm-intellisense
  timonwong.shellcheck
  VisualStudioExptTeam.vscodeintellicode
  vscode-icons-team.vscode-icons
  wingrunr21.vscode-ruby
  yzhang.markdown-all-in-one
  zxh404.vscode-proto3
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
