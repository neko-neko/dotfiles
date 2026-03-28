#!/usr/bin/env bash
set -euo pipefail

# doc-check: コード変更に影響を受ける md ドキュメントを検出する
# Usage:
#   doc-check                           # git diff (staged + unstaged) に対してチェック
#   doc-check --range HEAD~3..HEAD      # コミット範囲を指定
#   doc-check --files file1 file2 ...   # ファイルを直接指定

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/doc-utils.sh"

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

# --source-only が指定された場合は関数定義のみで終了
if [[ "${1:-}" == "--source-only" ]]; then return 0 2>/dev/null || exit 0; fi

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
