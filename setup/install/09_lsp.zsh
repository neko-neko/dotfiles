#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install LSP...'

formulas=(
  bash-language-server
  dockerfile-language-server
  hashicorp/tap/terraform-ls
  solargraph
  vscode-langservers-extracted
  yaml-language-server
)

for formula in ${formulas[@]}; do
  brew install ${formula}
done
