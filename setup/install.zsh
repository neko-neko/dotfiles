#!/bin/zsh
# include util functions
source ${HOME}/.dotfiles/setup/util.zsh

# zplug
util::confirm 'install zplug plugins?'
if [[ $? = 0 ]]; then
  source setup/install/zplug.zsh
  install::zplug
fi

# brew
util::confirm 'install brew formulas?'
if [[ $? = 0 ]]; then
  source setup/install/brew.zsh
  install::brew
fi

# brew
util::confirm 'install gnu tools?'
if [[ $? = 0 ]]; then
  source setup/install/gnu.zsh
  install::gnu
fi

# font
util::confirm 'install font files?'
if [[ $? = 0 ]]; then
  source setup/install/font.zsh
  install::font
fi

# golang
util::confirm 'install golang and libs?'
if [[ $? = 0 ]]; then
  source setup/install/go.zsh
  install::go
fi

# Ruby
util::confirm 'install Ruby and gems?'
if [[ $? = 0 ]]; then
  source setup/install/ruby.zsh
  install::ruby
fi

# Node.js
util::confirm 'install Node.js?'
if [[ $? = 0 ]]; then
  source setup/install/nodejs.zsh
  install::nodejs
fi

# Python
util::confirm 'install Python?'
if [[ $? = 0 ]]; then
  source setup/install/python.zsh
  install::python
fi

# PlantUML
util::confirm 'install PlantUML?'
if [[ $? = 0 ]]; then
  source setup/install/plantuml.zsh
  install::plantuml
fi

# Cask
util::confirm 'install brew cask?'
if [[ $? = 0 ]]; then
  source setup/install/brew_cask.zsh
  install::brew_cask
fi

# Toy
util::confirm 'install my toys?'
if [[ $? = 0 ]]; then
  source setup/install/toy.zsh
  install::toy
fi

# Finallize...
info 'cleanup...'
brew cleanup
brew cask cleanup
info 'done!'