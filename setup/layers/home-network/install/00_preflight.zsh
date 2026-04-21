#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh

util::info 'preflight: home-network layer...'

# 1Password CLI 認証確認
op::ensure_signed_in || exit 1

# config.local.zsh の存在と HOME_LAN_CIDR 設定の確認
local local_config="${HOME}/.dotfiles/setup/layers/home-network/config.local.zsh"
if [[ ! -f "$local_config" ]]; then
  util::error "config.local.zsh not found at $local_config"
  util::error "cp config.local.zsh.example config.local.zsh and edit it first"
  exit 1
fi

source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh
source "$local_config"

if [[ -z "$HOME_LAN_CIDR" ]]; then
  util::error "HOME_LAN_CIDR is not set in config.local.zsh"
  exit 1
fi

# sudo 認証先取り（後続の sudo brew services を対話なしに通すため）
util::info 'caching sudo credential...'
sudo -v || exit 1

util::info 'preflight passed'
