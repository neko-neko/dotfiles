#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

taps=(
  ktr0731/evans
  johanhaleby/kubetail
)

formulas=(
  autoconf
  binutils
  cmake
  curl
  diffutils
  diff-so-fancy
  evans
  fasd
  fzf
  gawk
  gettext
  gibo
  gnupg
  gnutls
  graphviz
  grip
  hub
  imagemagick
  istioctl
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
  pandoc
  protobuf
  readline
  ripgrep
  shellcheck
  source-highlight
  sops
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
brew link --force gettext
