#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  EditorConfig.EditorConfig
  PeterJausovec.vscode-docker
  dbaeumer.vscode-eslint
  DotJoshJohnson.xml
  esbenp.prettier-vscode
  flowtype.flow-for-vscode
  mauve.terraform
  ms-python.python
  msjsdiag.debugger-for-chrome
  naumovs.color-highlight
  nonylene.dark-molokai-theme
  peterj.proto
  redhat.vscode-yaml
  Tyriar.sort-lines
  vsmobile.vscode-react-native
  yzhang.markdown-all-in-one
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
