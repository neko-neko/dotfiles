#!/bin/zsh
# brew services 用の冪等ヘルパー。
# 依存: util.zsh (util::info / util::error)

# name の brew service が started 状態でなければ start する。
# sudo_required=true の場合は sudo 経由で起動。
# 使い方: service::ensure_started "adguardhome" true
service::ensure_started() {
  local name="$1"
  local sudo_required="${2:-false}"

  local status
  if [[ "$sudo_required" == "true" ]]; then
    status=$(sudo brew services list 2>/dev/null | awk -v n="$name" '$1==n {print $2}')
  else
    status=$(brew services list 2>/dev/null | awk -v n="$name" '$1==n {print $2}')
  fi

  if [[ "$status" == "started" ]]; then
    util::info "brew service '$name' is already started"
    return 0
  fi

  util::info "starting brew service '$name'"
  if [[ "$sudo_required" == "true" ]]; then
    sudo brew services start "$name"
  else
    brew services start "$name"
  fi
}

# name の brew service を restart する（状態問わず）。
service::restart() {
  local name="$1"
  local sudo_required="${2:-false}"

  util::info "restarting brew service '$name'"
  if [[ "$sudo_required" == "true" ]]; then
    sudo brew services restart "$name"
  else
    brew services restart "$name"
  fi
}
