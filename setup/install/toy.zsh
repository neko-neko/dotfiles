#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::toy() {
  info 'install my toys...'

  local casks=(
    wireshark
    xquartz
  )
  local formulas=(
    wine
    winetricks
  )
  local wine_plugins=(
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
}
