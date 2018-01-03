#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

for script in $(\ls ${HOME}/.dotfiles/setup/install); do   
  util::confirm "install ${script}?"
  if [[ $? = 0 ]]; then
    . ${HOME}/.dotfiles/setup/install/${script}
  fi
done

# Finallize...
util::info 'cleanup...'
brew cleanup
brew cask cleanup
util::info 'done!'
