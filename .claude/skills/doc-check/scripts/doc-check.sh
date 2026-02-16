#!/usr/bin/env bash
set -euo pipefail

# doc-check: コード変更に影響を受ける md ドキュメントを検出する
# Usage:
#   doc-check                           # git diff (staged + unstaged) に対してチェック
#   doc-check --range HEAD~3..HEAD      # コミット範囲を指定
#   doc-check --files file1 file2 ...   # ファイルを直接指定

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

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

# --- 変更ファイル取得 ---
get_changed_files() {
  local mode="${1:-default}"
  shift || true
  case "$mode" in
    range)
      git diff --name-only "$1" 2>/dev/null
      ;;
    files)
      printf '%s\n' "$@"
      ;;
    default)
      # staged + unstaged（新規は含まない）
      { git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; } | sort -u
      ;;
  esac
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

# --source-only が指定された場合は関数定義のみで終了
if [[ "${1:-}" == "--source-only" ]]; then return 0 2>/dev/null || exit 0; fi

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

# --- 引数パース ---
MODE="default"
FILES_ARGS=()
RANGE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range) MODE="range"; RANGE_ARG="$2"; shift 2 ;;
    --files) MODE="files"; shift; FILES_ARGS=("$@"); break ;;
    --source-only) exit 0 ;;
    *) echo "[doc-check] Unknown option: $1" >&2; exit 2 ;;
  esac
done

# --- メイン処理 ---
changed_files=""
case "$MODE" in
  range)   changed_files=$(get_changed_files range "$RANGE_ARG") ;;
  files)   changed_files=$(get_changed_files files "${FILES_ARGS[@]}") ;;
  default) changed_files=$(get_changed_files default) ;;
esac

if [[ -z "$changed_files" ]]; then
  echo "[doc-check] 変更ファイルがありません"
  exit 0
fi

changed_count=$(echo "$changed_files" | wc -l | tr -d ' ')
echo "[doc-check] 変更ファイル: ${changed_count}件"

# md ファイルを走査し depends-on とマッチング
# bash 3.2 互換: declare -A を使わず並列配列で管理
affected_docs=()
affected_matches=()   # doc_matches[i] corresponds to affected_docs[i]
affected_patterns=()  # doc_patterns[i] corresponds to affected_docs[i]

while IFS= read -r md_file; do
  deps=$(parse_depends_on "$md_file")
  [[ -z "$deps" ]] && continue

  matched_files=""
  matched_pattern=""
  while IFS= read -r dep; do
    while IFS= read -r changed; do
      if match_glob "$dep" "$changed"; then
        matched_files="${matched_files:+$matched_files, }$changed"
        matched_pattern="${matched_pattern:+$matched_pattern, }$dep"
      fi
    done <<< "$changed_files"
  done <<< "$deps"

  if [[ -n "$matched_files" ]]; then
    rel=$(_relpath "$md_file" "$REPO_ROOT")
    affected_docs+=("$rel")
    affected_matches+=("$matched_files")
    affected_patterns+=("$matched_pattern")
  fi
done < <(find "$REPO_ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*')

# 連鎖影響の検出
# 逆方向: 影響を受けていないが、影響を受けるドキュメントを参照している md を検出
chain_impacts=()
chain_sources=()  # chain_source[i] corresponds to chain_impacts[i]

if [[ ${#affected_docs[@]} -gt 0 ]]; then
while IFS= read -r md_file; do
  rel=$(_relpath "$md_file" "$REPO_ROOT")

  # 既に影響を受けているドキュメントはスキップ
  is_affected=false
  for a in "${affected_docs[@]}"; do
    if [[ "$a" == "$rel" ]]; then is_affected=true; break; fi
  done
  [[ "$is_affected" == true ]] && continue

  links=$(extract_md_links "$md_file" "$REPO_ROOT" 2>/dev/null || true)
  [[ -z "$links" ]] && continue
  while IFS= read -r link_target; do
    [[ -z "$link_target" ]] && continue
    for a in "${affected_docs[@]}"; do
      if [[ "$a" == "$link_target" ]]; then
        # 重複チェック
        already_in_chain=false
        for c in "${chain_impacts[@]+"${chain_impacts[@]}"}"; do
          if [[ "$c" == "$rel" ]]; then already_in_chain=true; break; fi
        done
        if [[ "$already_in_chain" == true ]]; then
          # 既に chain_impacts にある場合はソースを追記
          for i in "${!chain_impacts[@]}"; do
            if [[ "${chain_impacts[$i]}" == "$rel" ]]; then
              chain_sources[$i]="${chain_sources[$i]}, $a"
              break
            fi
          done
        else
          chain_impacts+=("$rel")
          chain_sources+=("$a")
        fi
      fi
    done
  done <<< "$links"
done < <(find "$REPO_ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*')
fi  # end of chain detection (affected_docs non-empty)

# --- 出力 ---
if [[ ${#affected_docs[@]} -eq 0 ]]; then
  echo "[doc-check] 影響を受けるドキュメント: 0件"
  exit 0
fi

echo "[doc-check] 影響を受けるドキュメント:"
echo ""
for i in "${!affected_docs[@]}"; do
  echo "  ${affected_docs[$i]}"
  echo "    depends-on: ${affected_patterns[$i]}"
  echo "    変更ファイル: ${affected_matches[$i]}"
  echo ""
done

if [[ ${#chain_impacts[@]} -gt 0 ]]; then
  echo "[doc-check] 連鎖影響（参照リンク経由）:"
  echo ""
  for i in "${!chain_impacts[@]}"; do
    echo "  ${chain_impacts[$i]} → ${chain_sources[$i]} (本文リンク)"
  done
  echo ""
fi

total_chain=${#chain_impacts[@]}
echo "[doc-check] 合計: 直接 ${#affected_docs[@]}件, 連鎖 ${total_chain}件"

if [[ ${#affected_docs[@]} -gt 0 || $total_chain -gt 0 ]]; then
  exit 1
fi
exit 0
