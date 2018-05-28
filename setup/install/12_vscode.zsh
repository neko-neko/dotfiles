#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure vscode...'

extensions=(
  EditorConfig.EditorConfig
  dbaeumer.vscode-eslint
  esbenp.prettier-vscode
  flowtype.flow-for-vscode
  vsmobile.vscode-react-native
  yzhang.markdown-all-in-one
)

for extension in ${extensions[@]}; do
  code --install-extension ${extension}
done
