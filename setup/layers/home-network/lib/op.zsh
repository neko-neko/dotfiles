#!/bin/zsh
# 1Password CLI (op) 用の冪等ヘルパー関数群。
# 依存: op >=2.13, util.zsh (util::error / util::info)

op::ensure_signed_in() {
  if ! op whoami &>/dev/null; then
    util::error "op CLI is not signed in."
    util::error "Run 'op signin' or enable 1Password Desktop app integration first."
    return 1
  fi
  return 0
}

# 冪等: title の Login item が vault に無ければ --generate-password で作成。
# 既存なら何もしない。戻り値は op item の状態に関係なく 0。
# 使い方: op::ensure_login_item "adguard-admin" "home-network"
op::ensure_login_item() {
  local title="$1"
  local vault="$2"
  local recipe="${3:-letters,digits,symbols,32}"

  if [[ -z "$title" || -z "$vault" ]]; then
    util::error "op::ensure_login_item requires title and vault"
    return 1
  fi

  if op item get "$title" --vault "$vault" &>/dev/null; then
    util::info "op item '$title' already exists in vault '$vault', skipping creation"
    return 0
  fi

  util::info "creating op item '$title' in vault '$vault'"
  op item create \
    --category Login \
    --title "$title" \
    --vault "$vault" \
    --generate-password="$recipe" \
    >/dev/null
}

# 副作用なしで item の存在だけを確認する。
# Returns 0 if the item exists, 1 otherwise. No output, no util::error.
# 冪等な自動生成フロー (expected-absent が正常パス) での判定用。
op::item_exists() {
  local title="$1"
  local vault="$2"
  op item get "$title" --vault "$vault" &>/dev/null
}

# 既存 item の存在確認だけを行う。未存在ならエラー付きで 1 を返す。
# 手動登録が前提の item (tailscale-authkey, syncthing-peer-macbook) 用。
op::require_item() {
  local title="$1"
  local vault="$2"

  if ! op item get "$title" --vault "$vault" &>/dev/null; then
    util::error "required op item '$title' not found in vault '$vault'"
    util::error "register it manually before running this script"
    return 1
  fi
  return 0
}

# secret reference から値を取得する。
# 例: op::read "op://home-network/adguard-admin/password"
op::read() {
  local ref="$1"
  op read "$ref"
}

# field の書き込み。既存値と同じなら skip (冪等)。
# 例: op::set_field "syncthing-apikey" "home-network" "password" "xxx"
op::set_field() {
  local title="$1"
  local vault="$2"
  local field="$3"
  local value="$4"

  local current
  current=$(op item get "$title" --vault "$vault" --fields "$field" --reveal 2>/dev/null)
  if [[ "$current" == "$value" ]]; then
    return 0
  fi

  op item edit "$title" --vault "$vault" "${field}=${value}" >/dev/null
}
