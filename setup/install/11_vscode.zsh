#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'
source ~/.zshenv && source ~/.zshrc

extensions=(
  FaroSystemAppender constructor
  anysphere.pyright
  Dart-Code.dart-code
  Dart-Code.flutter
  dbaeumer.vscode-eslint
  eamodio.gitlens
  EditorConfig.EditorConfig
  esbenp.prettier-vscode
  golang.go
  idleberg.nsis
  ms-azuretools.vscode-docker
  MS-CEINTL.vscode-language-pack-ja
  ms-kubernetes-tools.vscode-kubernetes-tools
  ms-python.python
  ms-python.vscode-pylance
  redhat.vscode-yaml
  tamasfe.even-better-toml
  XadillaX.viml
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
