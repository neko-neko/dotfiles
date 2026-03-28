#!/usr/bin/env bash
# doc-utils.sh: doc-check 共通ユーティリティ関数
# parse_depends_on, match_glob, extract_md_links, _relpath を提供する
# bash 3.2+ (macOS) 互換

# REPO_ROOT が未定義の場合のフォールバック
: "${REPO_ROOT:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# --- frontmatter パーサー ---
# 引数: md ファイルパス
# 出力: depends-on の各エントリを1行ずつ stdout に出力
parse_depends_on() {
  local file="$1"
  awk '
    BEGIN { in_fm=0; in_deps=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm && /^depends-on:[[:space:]]*$/ { in_deps=1; next }
    in_fm && in_deps && /^[[:space:]]+- / {
      sub(/^[[:space:]]+- /, "")
      sub(/[[:space:]]*#.*$/, "")
      # 前後の空白を除去
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      next
    }
    in_fm && in_deps && !/^[[:space:]]/ { in_deps=0 }
  ' "$file"
}

# --- glob マッチング ---
# 引数: pattern, filepath
# ** を再帰ワイルドカードとして処理
match_glob() {
  local pattern="$1" filepath="$2"
  # ? を一時プレースホルダーに（regex の ? と衝突させないため先に処理）
  local regex="${pattern//\?/__QUESTION__}"
  # . をエスケープ
  regex="${regex//./\\.}"
  # ** を一時プレースホルダーに
  regex="${regex//\*\*/__DOUBLE_STAR__}"
  # * を [^/]* に
  regex="${regex//\*/$'[^/]*'}"
  # **/ を (.*/)? に（0個以上のディレクトリにマッチ）
  regex="${regex//__DOUBLE_STAR__\//(.*\/)?}"
  # 残った ** を .* に（末尾の ** など）
  regex="${regex//__DOUBLE_STAR__/.*}"
  # ? プレースホルダーを [^/] に
  regex="${regex//__QUESTION__/$'[^/]'}"
  regex="^${regex}$"
  [[ "$filepath" =~ $regex ]]
}

# --- md リンク抽出 ---
# 引数: md ファイルパス, リポジトリルート（省略時は REPO_ROOT）
# 出力: リンク先の md ファイルパス（リポジトリルートからの相対パス）を1行ずつ出力
extract_md_links() {
  local file="$1"
  local repo_root="${2:-$REPO_ROOT}"
  local dir
  dir="$(dirname "$file")"

  # frontmatter をスキップして本文のみ処理
  # [text](path.md) 形式のリンクを抽出
  # 除外: 外部 URL (http:// https://), アンカーのみ (#section)
  awk '
    BEGIN { in_fm=0; past_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { in_fm=0; past_fm=1; next }
    !in_fm {
      line = $0
      while (match(line, /\[[^\]]*\]\(([^)]+)\)/)) {
        # リンク部分を抽出
        link_start = RSTART
        link_len = RLENGTH
        link_text = substr(line, link_start, link_len)
        # () 内を取得
        paren_start = index(link_text, "(")
        link_target = substr(link_text, paren_start + 1, length(link_text) - paren_start - 1)
        # アンカー部分を除去
        anchor_pos = index(link_target, "#")
        if (anchor_pos > 0) {
          link_target = substr(link_target, 1, anchor_pos - 1)
        }
        # フィルタリング
        if (link_target !~ /^#/ && link_target !~ /^https?:\/\// && link_target ~ /\.md$/) {
          print link_target
        }
        line = substr(line, link_start + link_len)
      }
    }
  ' "$file" | while IFS= read -r link; do
    # 相対パスをリポジトリルートからの相対パスに解決
    # macOS 互換: realpath に依存せず cd + pwd で解決
    local target_dir target_base resolved
    target_dir="$(cd "$dir" && cd "$(dirname "$link")" 2>/dev/null && pwd)" || continue
    target_base="$(basename "$link")"
    resolved="${target_dir}/${target_base}"
    # リポジトリルートからの相対パスに変換
    local rel_path="${resolved#$repo_root/}"
    echo "$rel_path"
  done
}

# --- ヘルパー: ファイルの相対パスを取得（realpath に依存しない） ---
_relpath() {
  local file="$1" base="$2"
  # python がなくても動くよう、文字列操作でフォールバック
  if command -v realpath >/dev/null 2>&1; then
    realpath --relative-to="$base" "$file" 2>/dev/null && return
  fi
  # フォールバック: prefix 除去
  echo "${file#$base/}"
}
