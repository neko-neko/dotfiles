#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.local.zsh

util::info 'install tailscale (formula)...'
brew install --formula tailscale

# Tailscale auth-key は手動発行前提。未登録ならここで abort。
op::require_item "$OP_ITEM_TAILSCALE_AUTHKEY" "$OP_VAULT" || {
  util::error "register tailscale auth-key in 1Password first:"
  util::error "  1. visit https://login.tailscale.com/admin/settings/keys"
  util::error "  2. generate a reusable=false, ephemeral=false, pre-approved=true key"
  util::error "     with tag 'tag:home-mac-mini'"
  util::error "  3. save as Login item '$OP_ITEM_TAILSCALE_AUTHKEY' in vault '$OP_VAULT'"
  exit 1
}

service::ensure_started tailscale true

local authkey
authkey=$(op::read "op://${OP_VAULT}/${OP_ITEM_TAILSCALE_AUTHKEY}/password")

util::info "tailscale up --advertise-routes=$HOME_LAN_CIDR"
sudo tailscale up \
  --advertise-routes="$HOME_LAN_CIDR" \
  --auth-key="$authkey" \
  --accept-dns=false \
  --reset

util::info 'tailscale subnet router is up'
sudo tailscale status | head -5
