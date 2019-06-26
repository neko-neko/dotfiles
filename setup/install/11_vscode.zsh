#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  alefragnani.project-manager
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
  Gruntfuggly.todo-tree
  ionutvmi.path-autocomplete
  joelday.docthis
  kumar-harsh.graphql-for-vscode
  mauve.terraform
  ms-azuretools.vscode-docker
  ms-kubernetes-tools.vscode-kubernetes-tools
  ms-python.python
  ms-vscode-remote.remote-containers
  ms-vscode.Go
  ms-vsliveshare.vsliveshare
  nonylene.dark-molokai-theme
  rebornix.ruby
  redhat.vscode-yaml
  shardulm94.trailing-spaces
  streetsidesoftware.code-spell-checker
  timonwong.shellcheck
  VisualStudioExptTeam.vscodeintellicode
  vscode-icons-team.vscode-icons
  WallabyJs.quokka-vscode
  yzhang.markdown-all-in-one
  zxh404.vscode-proto3
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
