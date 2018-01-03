#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

taps=(
  wata727/tflint
)
formulas=(
  ansible
  autoconf
  binutils
  cmake
  curl
  dep
  diffutils
  diff-so-fancy
  fzf
  gawk
  gibo
  gnupg
  gnutls
  graphviz
  hub
  imagemagick
  jq
  kubectl
  lua
  mas
  neovim
  nkf
  openssl
  packer
  pandoc
  readline
  source-highlight
  terraform
  tig
  tmux
  tree
)

brew upgrade
for tap in ${taps[@]}; do
  brew tap ${tap}
done
for formula in ${formulas[@]}; do
  brew install ${formula}
done
brew install --HEAD universal-ctags/universal-ctags/universal-ctags
