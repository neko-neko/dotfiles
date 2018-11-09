#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

taps=(
  johanhaleby/kubetail
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
  kubetail
  lua
  luarocks
  mas
  maven
  neovim
  nkf
  openssl
  packer
  pandoc
  protobuf
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

brew tap ${taps[@]}
for formula in ${formulas[@]}; do
  brew install ${formula}
done

brew install --HEAD universal-ctags/universal-ctags/universal-ctags
