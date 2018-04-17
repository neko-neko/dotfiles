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
  fasd
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
  kubectx
  kubernetes-helm
  leiningen
  lua
  mas
  neovim
  nodenv
  nkf
  openssl
  packer
  pandoc
  readline
  ripgrep
  source-highlight
  terraform
  tig
  tmux
  tree
  watchman
)

brew upgrade
for tap in ${taps[@]}; do
  brew tap ${tap}
done
for formula in ${formulas[@]}; do
  brew install ${formula}
done
brew install --HEAD universal-ctags/universal-ctags/universal-ctags
