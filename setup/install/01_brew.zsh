#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

formulas=(
  awscli
  autoconf
  binutils
  cmake
  curl
  cocoapods
  derailed/k9s/k9s
  diffutils
  diff-so-fancy
  ktr0731/evans/evans
  fasd
  fx
  fzf
  flutter
  gawk
  gcc
  gettext
  gibo
  gnupg
  gnutls
  grip
  gh
  ghq
  git
  imagemagick
  istioctl
  boz/repo/kail
  kubectl
  kubectx
  kubernetes-helm
  johanhaleby/kubetail/kubetail
  k9s
  krew
  openjdk
  jesseduffield/lazygit/lazygit
  jesseduffield/lazydocker/lazydocker
  lua
  luarocks
  mas
  neovim
  nmap
  nkf
  openssl
  protobuf
  postgresql
  readline
  ripgrep
  starship
  shellcheck
  source-highlight
  sops
  terminal-notifier
  tree
  tldr
)

brew upgrade

for formula in ${formulas[@]}; do
  brew install ${formula}
done

brew install --HEAD universal-ctags/universal-ctags/universal-ctags
brew link --force gettext
