#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install brew formulas...'

formulas=(
  autoconf
  binutils
  cmake
  curl
  derailed/k9s/k9s
  diffutils
  diff-so-fancy
  ktr0731/evans/evans
  fasd
  fzf
  gawk
  gcc
  gettext
  gibo
  gnupg
  gnutls
  graphviz
  grip
  gh
  imagemagick
  istioctl
  jq
  boz/repo/kail
  kubectl
  kubectx
  kubernetes-helm
  johanhaleby/kubetail/kubetail
  krew
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
  shellcheck
  source-highlight
  sops
  tree
  tldr
)

brew upgrade

for formula in ${formulas[@]}; do
  brew install ${formula}
done

brew install --HEAD universal-ctags/universal-ctags/universal-ctags
brew link --force gettext
