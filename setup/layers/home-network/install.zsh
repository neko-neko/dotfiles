#!/bin/zsh
# home-network layer entrypoint
# prerequisite: 共通 Brewfile / setup/install.zsh が完了している Mac mini 上で実行

local layer_dir="${HOME}/.dotfiles/setup/layers/home-network"
source ${HOME}/.dotfiles/setup/util.zsh

util::info '=== home-network layer setup ==='

# Brewfile
util::confirm "install home-network Brewfile?"
if [[ $? = 0 ]]; then
  brew bundle --file "${layer_dir}/Brewfile"
fi

# install scripts (番号順)
for script in $(\ls "${layer_dir}/install" | sort); do
  util::confirm "run setup script ${script}?"
  if [[ $? = 0 ]]; then
    . "${layer_dir}/install/${script}"
  fi
done

util::info '=== home-network layer setup complete ==='
util::info 'see README.md for post-install steps'
