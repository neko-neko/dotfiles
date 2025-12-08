#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::confirm "install packages from Brewfile?"
if [[ $? = 0 ]]; then
  brew bundle --file ${HOME}/.dotfiles/Brewfile
fi

for script in $(\ls ${HOME}/.dotfiles/setup/install); do
  util::confirm "run setup script ${script}?"
  if [[ $? = 0 ]]; then
    . ${HOME}/.dotfiles/setup/install/${script}
  fi
done

# Finallize...
util::info 'cleanup...'
brew cleanup
util::info 'done!'
