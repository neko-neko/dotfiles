#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'install my toys...'

casks=(
  wireshark
  xquartz
)
formulas=(
  wine
  winetricks
)
wine_plugins=(
  allfonts
  d3dx9_43
  d3dx10_43
  d3dx11_43
  directmusic
  dsound
  vcrun2005
  vcrun2008
  vcrun2010
  vcrun2012
  vcrun2013
  vcrun2015
  vcrun6
)

brew cask install ${casks[@]}
brew install ${formulas[@]}
winetricks ${wine_plugins[@]}
