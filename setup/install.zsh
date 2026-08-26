#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

# This installs the COMMON Brewfile only (packages suitable for both the
# Hermes server and a Mac client). For machine-specific packages, also run
# the relevant layer's install.zsh after this completes:
#   setup/layers/hermes-server/install.zsh  (Tailscale Hermes server)
#   setup/layers/mac-client/install.zsh     (personal Mac client)
#   setup/layers/home-network/install.zsh   (Jellyfin/media/home-network box)
# See README.md "Installation" for details.
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
