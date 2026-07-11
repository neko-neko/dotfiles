# shellcheck shell=bash
# drop-upload core — scripts/ から source される純粋関数群
# 副作用を持つのは validate_paths のファイル存在検査のみ
# テスト: spec/drop-upload_spec.sh

# %XX パーセントエンコードをデコードする（UTF-8 バイト列対応）
percent_decode() {
  local encoded="${1//\\/\\\\}"
  printf '%b' "${encoded//\%/\\x}"
}

# Ghostty がペーストした1行からファイルパスを抽出し、1行1件で出力する。
# ペースト形式（素のパス / backslash エスケープ / クォート囲み / file:// URL）に
# 依存しない多段フォールバック。空行は exit 1
parse_dropped_paths() {
  local line="${1-}"
  line="${line//$'\r'/}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -n "$line" ]] || return 1

  if [[ "$line" == file://* ]]; then
    local -a tokens
    IFS=' ' read -r -a tokens <<<"$line"
    local token
    for token in "${tokens[@]}"; do
      printf '%s\n' "$(percent_decode "${token#file://}")"
    done
    return 0
  fi

  local tokenized
  if tokenized=$(printf '%s\n' "$line" | xargs -n1 printf '%s\n' 2>/dev/null) \
    && [[ -n "$tokenized" ]]; then
    printf '%s\n' "$tokenized"
    return 0
  fi

  # 不正クォート（アポストロフィ入りファイル名等）→ 行全体を1パスとして扱う
  printf '%s\n' "$line"
}

# ssh の argv から接続先を抽出し "dest=<user@host>"（+ 任意で "port=<n>"）を出力する。
# 値を取るオプションはスキップし、-l / -p は合成する。非 ssh は exit 1
extract_ssh_target() {
  local dest="" port="" user=""
  [[ "${1-}" == "ssh" ]] || return 1
  shift
  while (($#)); do
    case "$1" in
      -p) [[ $# -ge 2 ]] || return 1; port="$2"; shift 2 ;;
      -p?*) port="${1#-p}"; shift ;;
      -l) [[ $# -ge 2 ]] || return 1; user="$2"; shift 2 ;;
      -l?*) user="${1#-l}"; shift ;;
      -[bcDeEFiIJLmoOQRSWw]) [[ $# -ge 2 ]] || return 1; shift 2 ;;
      -[bcDeEFiIJLmoOQRSWw]?*) shift ;;
      -*) shift ;;
      *) dest="$1"; break ;;
    esac
  done
  [[ -n "$dest" ]] || return 1

  if [[ "$dest" == ssh://* ]]; then
    dest="${dest#ssh://}"
    dest="${dest%%/*}"
    if [[ "$dest" == *\]* ]]; then
      # IPv6 ブラケット形式: [::1] / user@[::1]:2222
      local suffix="${dest##*\]}"
      if [[ "$suffix" == :* ]]; then
        port="${suffix#:}"
        dest="${dest%"$suffix"}"
      fi
    elif [[ "$dest" == *:* ]]; then
      port="${dest##*:}"
      dest="${dest%:*}"
    fi
  fi

  if [[ -n "$user" && "$dest" != *@* ]]; then
    dest="${user}@${dest}"
  fi

  printf 'dest=%s\n' "$dest"
  if [[ -n "$port" ]]; then
    printf 'port=%s\n' "$port"
  fi
  return 0
}

# herdr pane process-info の JSON envelope から ssh プロセスの argv を
# 1行1トークンで出力する。argv 不在時は cmdline の空白分割にフォールバック。
# ssh プロセスが無ければ exit 1
extract_ssh_argv_from_process_info() {
  local json="${1-}" argv
  [[ -n "$json" ]] || return 1
  argv=$(jq -r '
    [.result.process_info.foreground_processes[]?
      | select(.name == "ssh" or .argv0 == "ssh")][0]
    | if . == null then empty
      elif has("argv") then .argv[]
      else (.cmdline // empty | split(" ")[] | select(. != ""))
      end
  ' <<<"$json" 2>/dev/null) || return 1
  [[ -n "$argv" ]] || return 1
  printf '%s\n' "$argv"
}

# 存在するパスを stdout、存在しないパスを stderr へ。全滅なら exit 1
validate_paths() {
  local path found=0
  for path in "$@"; do
    if [[ -e "$path" ]]; then
      printf '%s\n' "$path"
      found=1
    else
      echo "drop-upload: not found: $path" >&2
    fi
  done
  [[ "$found" == 1 ]] || return 1
  return 0
}

# send-text 用にパスをシェルセーフに引用する
quote_for_remote() {
  printf '%q\n' "$1"
}
