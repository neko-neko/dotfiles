#!/bin/zsh
# mac-client layer entrypoint
# prerequisite: 共通 Brewfile / setup/install.zsh が完了している Mac クライアント機上で実行

local layer_dir="${HOME}/.dotfiles/setup/layers/mac-client"
source ${HOME}/.dotfiles/setup/util.zsh

util::info '=== mac-client layer setup ==='

# Brewfile
util::confirm "install mac-client Brewfile?"
if [[ $? = 0 ]]; then
  brew bundle --file "${layer_dir}/Brewfile"
fi

util::info '=== mac-client layer setup complete ==='
