#!/bin/zsh
# home-network layer 既定値。secret は含めない。
# 端末固有値は config.local.zsh で上書きすること。

# 1Password vault / item 名
OP_VAULT="home-network"
OP_ITEM_TAILSCALE_AUTHKEY="tailscale-authkey"
OP_ITEM_ADGUARD_ADMIN="adguard-admin"
OP_ITEM_SYNCTHING_GUI="syncthing-gui"
OP_ITEM_SYNCTHING_APIKEY="syncthing-apikey"
OP_ITEM_SYNCTHING_PEER_MACBOOK="syncthing-peer-macbook"

# AdGuard Home
ADGUARD_ADMIN_USER="admin"
ADGUARD_WEB_ADDRESS="0.0.0.0:3000"
ADGUARD_DNS_BIND="0.0.0.0"
ADGUARD_DNS_PORT="53"
ADGUARD_UPSTREAM_DNS=(
  "1.1.1.1"
  "1.0.0.1"
  "8.8.8.8"
)
ADGUARD_FILTERS=(
  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt|AdGuard DNS filter"
  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus|Peter Lowe's List"
)

# Syncthing
SYNCTHING_GUI_USER="admin"
SYNCTHING_GUI_ADDRESS="127.0.0.1:8384"
SYNCTHING_CLAUDE_FOLDER_ID="claude-home"
SYNCTHING_CLAUDE_FOLDER_LABEL="Claude Home"
SYNCTHING_CLAUDE_FOLDER_PATH="${HOME}/.claude"
SYNCTHING_CONFIG_DIR="${HOME}/Library/Application Support/Syncthing"

# Tailscale: advertise-routes に使う LAN CIDR は config.local.zsh で必須設定
# HOME_LAN_CIDR="192.168.10.0/24"
HOME_LAN_CIDR="${HOME_LAN_CIDR:-}"
