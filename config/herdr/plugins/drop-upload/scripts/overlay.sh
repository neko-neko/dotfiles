#!/usr/bin/env bash
#
# drop-upload overlay — Ghostty の D&D ペースト（ファイルパス）を受けて scp 転送し、
# 対象ペインへリモートパスを send-text する drop-target ペイン。
# action-start.sh が STATE_DIR に凍結した target_pane / process_info.json を前提とする。
# set -e は使わない: 転送失敗でループを終了させず、リトライ可能に保つ
set -uo pipefail

source "${BASH_SOURCE[0]%/*}/../lib/core.sh"

state_dir=""
target_pane=""
dest=""
port=""
remote_dir="uploads"
remote_dir_ready=0

say() { printf '%s\n' "$*"; }

cleanup() {
  rm -f "$state_dir/target_pane" "$state_dir/process_info.json" 2>/dev/null
}

load_state() {
  if [[ -f "$state_dir/target_pane" ]]; then
    target_pane=$(<"$state_dir/target_pane")
  fi
}

resolve_ssh_target() {
  local argv_lines target_info
  if [[ -f "$state_dir/process_info.json" ]] \
    && argv_lines=$(extract_ssh_argv_from_process_info "$(cat "$state_dir/process_info.json")"); then
    local -a argv=()
    while IFS= read -r token; do argv+=("$token"); done <<<"$argv_lines"
    if target_info=$(extract_ssh_target "${argv[@]}"); then
      dest=$(sed -n 's/^dest=//p' <<<"$target_info")
      port=$(sed -n 's/^port=//p' <<<"$target_info")
    fi
  fi
  if [[ -z "$dest" ]]; then
    say "対象ペインから ssh 接続先を検出できませんでした"
    read -r -p "SSH destination (user@host, 空 Enter でキャンセル): " dest || dest=""
    [[ -n "$dest" ]] || exit 0
  fi
}

load_settings() {
  local conf="${HERDR_PLUGIN_CONFIG_DIR:-}/settings.conf" configured
  if [[ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" && -f "$conf" ]]; then
    configured=$(sed -n 's/^remote_dir=//p' "$conf" | tail -1)
    if [[ -n "$configured" ]]; then
      # リモートコマンドへ補間されるため、安全な文字のみ許可し .. セグメントを拒否する
      if [[ "$configured" =~ ^[A-Za-z0-9._][A-Za-z0-9._/-]*$ ]] \
        && [[ ! "$configured" =~ (^|/)\.\.(/|$) ]]; then
        remote_dir="$configured"
      else
        echo "drop-upload: invalid remote_dir in settings.conf — falling back to '$remote_dir'" >&2
      fi
    fi
  fi
}

ensure_remote_dir() {
  if (( remote_dir_ready )); then
    return 0
  fi
  local -a ssh_cmd=(ssh)
  if [[ -n "$port" ]]; then
    ssh_cmd+=(-p "$port")
  fi
  ssh_cmd+=("$dest" "mkdir -p -- \"\$HOME/$remote_dir\"")
  if ! "${ssh_cmd[@]}"; then
    echo "drop-upload: failed to create remote dir '$remote_dir' on $dest" >&2
    return 1
  fi
  remote_dir_ready=1
}

notify_target() {
  local text="$1"
  if [[ -z "$target_pane" ]]; then
    say "no target pane — copy manually: $text"
    return 0
  fi
  if herdr pane process-info --pane "$target_pane" >/dev/null 2>&1; then
    herdr pane send-text "$target_pane" "$text"
    say "sent to pane $target_pane"
  else
    say "target pane closed — copy manually: $text"
  fi
}

do_upload() {
  ensure_remote_dir || return 0
  local -a scp_cmd=(scp -o ConnectTimeout=10)
  if [[ -n "$port" ]]; then
    scp_cmd+=(-P "$port")
  fi
  scp_cmd+=(-- "$@" "$dest:$remote_dir/")
  local rc=0
  "${scp_cmd[@]}" || rc=$?
  if (( rc != 0 )); then
    echo "drop-upload: scp exited with $rc" >&2
    say "upload failed — もう一度ドロップしてリトライできます"
    return 0
  fi
  local file
  local -a remote_paths=()
  for file in "$@"; do
    remote_paths+=("$(quote_for_remote "$remote_dir/$(basename "$file")")")
  done
  say "uploaded: ${remote_paths[*]}"
  notify_target "${remote_paths[*]}"
}

process_line() {
  local raw="$1" parsed valid path
  parsed=$(parse_dropped_paths "$raw") || return 0
  local -a files=()
  while IFS= read -r path; do files+=("$path"); done <<<"$parsed"
  if ! valid=$(validate_paths "${files[@]}"); then
    echo "drop-upload: ドロップされたパスが存在しません" >&2
    return 0
  fi
  local -a existing=()
  while IFS= read -r path; do existing+=("$path"); done <<<"$valid"
  do_upload "${existing[@]}"
}

main() {
  if [[ -z "${HERDR_PLUGIN_STATE_DIR:-}" ]]; then
    echo "drop-upload: not running as a herdr plugin pane" >&2
    echo "manual fallback: scp <file> <host>:~/uploads/" >&2
    exit 1
  fi
  state_dir="$HERDR_PLUGIN_STATE_DIR"
  trap cleanup EXIT INT TERM

  load_state
  resolve_ssh_target
  load_settings

  say "── drop-upload ──"
  say "target: ${target_pane:-<none>} → ${dest}:${remote_dir}/"
  say "Finder からこのペインへファイルをドラッグ（空行 or q で終了）"

  local line
  while IFS= read -r line; do
    case "$line" in
      ''|q|Q) break ;;
    esac
    process_line "$line"
  done
  exit 0
}

main "$@"
