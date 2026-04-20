#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/op.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/lib/service.zsh
source ${HOME}/.dotfiles/setup/layers/home-network/config.zsh

# REST API の準備完了を待つ。最大 30 秒で timeout。
# 使い方: syncthing::wait_rest_ready "$api_base" "$apikey"
syncthing::wait_rest_ready() {
  local base="$1"
  local key="$2"
  local waited=0
  while (( waited < 30 )); do
    if curl -sS -o /dev/null -H "X-API-Key: $key" "${base}/rest/system/ping" &>/dev/null; then
      util::info "syncthing REST API ready after ${waited}s"
      return 0
    fi
    sleep 1
    ((waited++))
  done
  util::error "syncthing REST API did not respond within 30s"
  return 1
}

util::info 'install syncthing...'
brew install syncthing

# 初回起動: config.xml が無ければ syncthing を start して自動生成させる
local config_xml="${SYNCTHING_CONFIG_DIR}/config.xml"
local api_base="http://${SYNCTHING_GUI_ADDRESS}"

if [[ ! -f "$config_xml" ]]; then
  util::info 'first run: starting syncthing to generate config.xml'
  service::ensure_started syncthing false

  local waited=0
  while [[ ! -f "$config_xml" && $waited -lt 30 ]]; do
    sleep 1
    ((waited++))
  done

  if [[ ! -f "$config_xml" ]]; then
    util::error "syncthing config.xml was not created within 30s"
    exit 1
  fi
  util::info "config.xml created after ${waited}s"
else
  service::ensure_started syncthing false
fi

# config.xml から API key を抽出 (REST 準備ポーリングに使う)
local apikey
apikey=$(grep -oE '<apikey>[^<]+</apikey>' "$config_xml" | sed -E 's|<apikey>(.*)</apikey>|\1|')
if [[ -z "$apikey" ]]; then
  util::error "failed to extract apikey from $config_xml"
  exit 1
fi

# REST API が応答するまで待機 (後続の PUT 呼び出しが 503 で失敗するのを防ぐ)
syncthing::wait_rest_ready "$api_base" "$apikey" || exit 1

# API key を 1Password に書き戻し（冪等、既存と同値なら skip）
if ! op::item_exists "$OP_ITEM_SYNCTHING_APIKEY" "$OP_VAULT"; then
  util::info "creating op item '$OP_ITEM_SYNCTHING_APIKEY'"
  op item create \
    --category Password \
    --title "$OP_ITEM_SYNCTHING_APIKEY" \
    --vault "$OP_VAULT" \
    "password=$apikey" \
    >/dev/null
else
  op::set_field "$OP_ITEM_SYNCTHING_APIKEY" "$OP_VAULT" "password" "$apikey"
fi

# GUI パスワード item を冪等生成
op::ensure_login_item "$OP_ITEM_SYNCTHING_GUI" "$OP_VAULT"

local gui_pw
gui_pw=$(op::read "op://${OP_VAULT}/${OP_ITEM_SYNCTHING_GUI}/password")

# 対向デバイス (MacBook) の Device ID を取得（手動登録前提）
op::require_item "$OP_ITEM_SYNCTHING_PEER_MACBOOK" "$OP_VAULT" || {
  util::error "register MacBook's syncthing device id in 1password:"
  util::error "  1. on MacBook: syncthing cli show system | grep myID"
  util::error "  2. save as Secure Note '$OP_ITEM_SYNCTHING_PEER_MACBOOK' in vault '$OP_VAULT'"
  util::error "  3. put the device id in 'notesPlain' field"
  exit 1
}

local peer_id
peer_id=$(op item get "$OP_ITEM_SYNCTHING_PEER_MACBOOK" --vault "$OP_VAULT" --fields notesPlain --reveal)
peer_id=$(echo "$peer_id" | tr -d '[:space:]')
if [[ -z "$peer_id" ]]; then
  util::error "peer device id not found in item $OP_ITEM_SYNCTHING_PEER_MACBOOK"
  exit 1
fi

# REST API で設定を更新 (api_base は上で定義済み)
# -f: fail on HTTP 4xx/5xx so we can abort instead of proceeding with bad state
local curl_opts=(-sSf -H "X-API-Key: $apikey" -H "Content-Type: application/json")

util::info "registering peer device $peer_id via REST API"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/devices/${peer_id}" -d @- <<EOF || { util::error "failed to register peer device via REST"; exit 1; }
{
  "deviceID": "${peer_id}",
  "name": "MacBook",
  "addresses": ["dynamic"],
  "compression": "metadata",
  "introducer": false,
  "paused": false
}
EOF

util::info "registering folder ${SYNCTHING_CLAUDE_FOLDER_ID} via REST API"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/folders/${SYNCTHING_CLAUDE_FOLDER_ID}" -d @- <<EOF || { util::error "failed to register folder via REST"; exit 1; }
{
  "id": "${SYNCTHING_CLAUDE_FOLDER_ID}",
  "label": "${SYNCTHING_CLAUDE_FOLDER_LABEL}",
  "path": "${SYNCTHING_CLAUDE_FOLDER_PATH}",
  "type": "sendreceive",
  "devices": [
    {"deviceID": "${peer_id}"}
  ],
  "rescanIntervalS": 3600,
  "fsWatcherEnabled": true,
  "fsWatcherDelayS": 10
}
EOF

# .stignore を生成
util::info "writing $SYNCTHING_CLAUDE_FOLDER_PATH/.stignore"
cat > "${SYNCTHING_CLAUDE_FOLDER_PATH}/.stignore" <<'EOF'
// home-network layer Claude home sync excludes
plugins
telemetry
cache
file-history
shell-snapshots
ide
statsig
session-env
chrome
debug
usage-data
downloads
paste-cache
*.bak
*.backup.*
.DS_Store
EOF

# GUI パスワードを設定（REST API）
util::info "setting syncthing GUI credentials"
curl "${curl_opts[@]}" -X PUT "${api_base}/rest/config/gui" -d @- <<EOF || { util::error "failed to set GUI credentials via REST"; exit 1; }
{
  "enabled": true,
  "address": "${SYNCTHING_GUI_ADDRESS}",
  "user": "${SYNCTHING_GUI_USER}",
  "password": "${gui_pw}",
  "useTLS": false
}
EOF

service::restart syncthing false

util::info 'syncthing configured'
util::info "gui: http://${SYNCTHING_GUI_ADDRESS}"
util::info "gui user: ${SYNCTHING_GUI_USER}"
util::info "gui password: stored in 1password: op://${OP_VAULT}/${OP_ITEM_SYNCTHING_GUI}/password"
util::info "NEXT: on MacBook, accept this device's pairing request and approve the '${SYNCTHING_CLAUDE_FOLDER_ID}' folder share"
