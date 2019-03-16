#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

taps=(
  johanhaleby/kubetail
)

formulas=(
  autoconf
  binutils
  cmake
  curl
  diffutils
  diff-so-fancy
  fasd
  fzf
  gawk
  gettext
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
  pandoc
  protobuf
  readline
  ripgrep
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
