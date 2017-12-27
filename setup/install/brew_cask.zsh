#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

install::brew_cask() {
  util::info 'install brew cask formulas...'

  local taps=(
    caskroom/cask
  )

  local casks=(
    alfred
    atom
    caffeine
    docker
    firefox
    google-chrome
    google-japanese-ime
    iterm2
    java
    karabiner-elements
    licecap
    mysqlworkbench
    nosleep
    shiftit
    slack
    vagrant
    virtualbox
  )

  brew tap ${taps[@]}
  brew cask install ${casks[@]}
  apm install sync-settings
}
