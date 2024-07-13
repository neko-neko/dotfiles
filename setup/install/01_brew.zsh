#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

formulas=(
  autoconf
  awscli
  boz/repo/kail
  cmake
  cocoapods
  curl
  derailed/k9s/k9s
  diffutils
  flutter
  fzf
  gawk
  gcc
  gh
  ghq
  gibo
  git
  git-delta
  git-lfs
  gnupg
  gnutls
  grip
  imagemagick
  istioctl
  johanhaleby/kubetail/kubetail
  k9s
  krew
  ktr0731/evans/evans
  kubectl
  kubectx
  kubernetes-helm
  lazygit
  libpq
  mise
  nkf
  nmap
  openjdk
  openssl
  postgresql
  protobuf
  readline
  ripgrep
  rye
  sheldon
  shellcheck
  sops
  source-highlight
  starship
  terminal-notifier
  tree
)

brew upgrade

for formula in ${formulas[@]}; do
  brew install ${formula}
done
