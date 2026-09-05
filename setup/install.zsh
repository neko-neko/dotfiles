#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

# This installs the shared development baseline Brewfile only. Machine-role and
# service-overlay packages live in layers; install them afterwards with:
#   ./setup/layer.zsh <layer>...     (run with no arguments to list them)
# See README.md "Layer composition" for the supported compositions.
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
