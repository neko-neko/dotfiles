#!/bin/zsh
# hermes-server layer entrypoint
# prerequisite: 共通 Brewfile / setup/install.zsh が完了している Hermes サーバー機上で実行

local layer_dir="${HOME}/.dotfiles/setup/layers/hermes-server"
source ${HOME}/.dotfiles/setup/util.zsh

util::info '=== hermes-server layer setup ==='

# Brewfile
util::confirm "install hermes-server Brewfile?"
if [[ $? = 0 ]]; then
  brew bundle --file "${layer_dir}/Brewfile"
fi

util::info '=== hermes-server layer setup complete ==='
