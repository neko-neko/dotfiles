#!/bin/zsh
# Syncthing セットアップ — デーモン起動 + REST API で kanban フォルダ登録

SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h:h}"

source "${DOTFILES_DIR}/setup/util.zsh"

SYNCTHING_API="http://localhost:8384"
SYNCTHING_CONFIG_XML="${HOME}/Library/Application Support/Syncthing/config.xml"
KANBAN_DIR="${HOME}/.claude/kanban"
FOLDER_ID="claude-kanban"

# --- 1. Syncthing デーモン起動 ---
if ! brew services list | grep -q "syncthing.*started"; then
  util::info "Starting Syncthing service..."
  brew services start syncthing
fi

# --- 2. ヘルスチェック（最大30秒） ---
util::info "Waiting for Syncthing to be ready..."
max_retries=15
retry=0
while [[ ${retry} -lt ${max_retries} ]]; do
  if curl -sf "${SYNCTHING_API}/rest/noauth/health" &>/dev/null; then
    break
  fi
  retry=$((retry + 1))
  sleep 2
done

if [[ ${retry} -ge ${max_retries} ]]; then
  util::error "Syncthing did not become ready within 30 seconds."
  return 1
fi
util::info "Syncthing is ready."

# --- 3. API キー取得 ---
if [[ ! -f "${SYNCTHING_CONFIG_XML}" ]]; then
  util::error "Syncthing config not found at: ${SYNCTHING_CONFIG_XML}"
  return 1
fi

# macOS の grep は -P (Perl regex) 非対応のため sed を使用
API_KEY=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "${SYNCTHING_CONFIG_XML}")

if [[ -z "${API_KEY}" ]]; then
  util::error "Failed to extract API key from config.xml"
  return 1
fi

st_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "${method}" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    "${SYNCTHING_API}${endpoint}" "$@"
}

# --- 4. 自デバイスID 取得 ---
DEVICE_ID=$(st_api GET "/rest/system/status" | jq -r '.myID')
if [[ -z "${DEVICE_ID}" || "${DEVICE_ID}" = "null" ]]; then
  util::error "Failed to get device ID from Syncthing."
  return 1
fi

# --- 5. kanban ディレクトリ作成 ---
if [[ ! -d "${KANBAN_DIR}" ]]; then
  util::info "Creating ${KANBAN_DIR}..."
  mkdir -p "${KANBAN_DIR}"
fi

# --- 6. 共有フォルダ登録 ---
st_api GET "/rest/config/folders/${FOLDER_ID}" >/dev/null 2>&1
folder_check_status=$?
if [[ ${folder_check_status} -eq 0 ]]; then
  util::info "Folder '${FOLDER_ID}' already exists in Syncthing. Skipping."
else
  util::info "Registering folder '${FOLDER_ID}' in Syncthing..."

  defaults=$(st_api GET "/rest/config/defaults/folder")
  folder_config=$(echo "${defaults}" | jq \
    --arg id "${FOLDER_ID}" \
    --arg label "Claude Kanban" \
    --arg path "${KANBAN_DIR}" \
    '. + {id: $id, label: $label, path: $path, type: "sendreceive"}')

  result=$(st_api POST "/rest/config/folders" -d "${folder_config}")
  if [[ $? -ne 0 ]]; then
    util::error "Failed to register folder."
    return 1
  fi
  util::info "Folder '${FOLDER_ID}' registered successfully."
fi

# --- 7. 完了 + ペアリング案内 ---
util::info "=== Syncthing Setup Complete ==="
util::info "Your Device ID:"
echo "${DEVICE_ID}"
echo ""
util::info "To sync with another machine:"
util::info "  1. Run this setup on the other machine"
util::info "  2. Add each other's Device ID in Syncthing GUI (http://localhost:8384)"
util::info "  3. Share the '${FOLDER_ID}' folder with the paired device"
