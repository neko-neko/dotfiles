#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  EditorConfig.EditorConfig
  PeterJausovec.vscode-docker
  dbaeumer.vscode-eslint
  esbenp.prettier-vscode
  flowtype.flow-for-vscode
  msjsdiag.debugger-for-chrome
  nonylene.dark-molokai-theme
  redhat.vscode-yaml
  Tyriar.sort-lines
  vsmobile.vscode-react-native
  yzhang.markdown-all-in-one
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
