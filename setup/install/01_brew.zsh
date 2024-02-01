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
  diff-so-fancy
  diffutils
  flutter
  fx
  fzf
  gawk
  gcc
  gh
  ghq
  gibo
  git
  git-delta
  gnupg
  gnutls
  grip
  imagemagick
  istioctl
  jesseduffield/lazydocker/lazydocker
  jesseduffield/lazygit/lazygit
  johanhaleby/kubetail/kubetail
  k9s
  krew
  ktr0731/evans/evans
  kubectl
  kubectx
  kubernetes-helm
  libpq
  mise
  neovim
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
