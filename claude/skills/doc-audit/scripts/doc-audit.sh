#!/usr/bin/env bash
# doc-audit.sh: ドキュメント監査スクリプト
# 5種類の検出機能を持ち、JSON で結果を出力する
# bash 3.2+ (macOS) 互換
#
# 前提:
#   - doc-utils.sh (parse_depends_on, match_glob, extract_md_links, _relpath) が利用可能
#   - macOS の date コマンド (-r <timestamp>) を使用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../doc-check/scripts/lib/doc-utils.sh"

# --- JSON ヘルパー ---
# jq に依存しない JSON エスケープ
_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# --- 1. check_broken_deps ---
# depends-on に宣言されたパスが存在するか確認
# glob パターンの場合は find + match_glob で1件でもマッチするか確認
# JSON 配列を返す: [{"doc":"path","missing":"path"}]
check_broken_deps() {
  local repo_root="$1"
  local results=""
  local first=true

  while IFS= read -r md_file; do
    local deps
    deps=$(parse_depends_on "$md_file")
    [[ -z "$deps" ]] && continue

    local rel_doc
    rel_doc=$(_relpath "$md_file" "$repo_root")

    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue

      # glob パターンか判定（*, ?, ** を含む）
      if [[ "$dep" == *'*'* ]] || [[ "$dep" == *'?'* ]]; then
        # glob: find でファイルを列挙し match_glob で1件でもマッチするか確認
        local found=false
        while IFS= read -r candidate; do
          local rel_candidate
          rel_candidate=$(_relpath "$candidate" "$repo_root")
          if match_glob "$dep" "$rel_candidate"; then
            found=true
            break
          fi
        done < <(find "$repo_root" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)
        if [[ "$found" == false ]]; then
          [[ "$first" == true ]] && first=false || results="${results},"
          results="${results}{\"doc\":\"$(_json_escape "$rel_doc")\",\"missing\":\"$(_json_escape "$dep")\"}"
        fi
      else
        # 具体パス: 存在確認
        if [[ ! -e "${repo_root}/${dep}" ]]; then
          [[ "$first" == true ]] && first=false || results="${results},"
          results="${results}{\"doc\":\"$(_json_escape "$rel_doc")\",\"missing\":\"$(_json_escape "$dep")\"}"
        fi
      fi
    done <<< "$deps"
  done < <(find "$repo_root" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)

  printf '[%s]' "$results"
}

# --- 2. check_dead_links ---
# 全 md の本文中 markdown リンクの先が存在するか確認
# JSON 配列: [{"doc":"path","link":"path","line":N}]
check_dead_links() {
  local repo_root="$1"
  local results=""
  local first=true

  while IFS= read -r md_file; do
    local rel_doc
    rel_doc=$(_relpath "$md_file" "$repo_root")
    local dir
    dir="$(dirname "$md_file")"

    # 行番号付きでリンクを抽出（process substitution でサブシェル回避）
    local awk_output
    awk_output=$(awk '
      BEGIN { in_fm=0 }
      NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
      in_fm && /^---[[:space:]]*$/ { in_fm=0; next }
      !in_fm {
        line = $0
        while (match(line, /\[[^\]]*\]\(([^)]+)\)/)) {
          link_start = RSTART
          link_len = RLENGTH
          link_text = substr(line, link_start, link_len)
          paren_start = index(link_text, "(")
          link_target = substr(link_text, paren_start + 1, length(link_text) - paren_start - 1)
          anchor_pos = index(link_target, "#")
          if (anchor_pos > 0) link_target = substr(link_target, 1, anchor_pos - 1)
          if (link_target !~ /^#/ && link_target !~ /^https?:\/\//) {
            print NR "\t" link_target
          }
          line = substr(line, link_start + link_len)
        }
      }
    ' "$md_file")

    [[ -z "$awk_output" ]] && continue

    while IFS=$'\t' read -r lineno link; do
      [[ -z "$link" ]] && continue
      # 相対パスをドキュメント基準で解決
      local target_path
      if [[ "$link" == /* ]]; then
        target_path="${repo_root}${link}"
      else
        target_path="${dir}/${link}"
      fi
      if [[ ! -e "$target_path" ]]; then
        [[ "$first" == true ]] && first=false || results="${results},"
        results="${results}{\"doc\":\"$(_json_escape "$rel_doc")\",\"link\":\"$(_json_escape "$link")\",\"line\":${lineno}}"
      fi
    done <<< "$awk_output"
  done < <(find "$repo_root" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)

  printf '[%s]' "$results"
}

# --- 3. check_undeclared_deps ---
# 本文中のバッククォート内ファイルパス言及を抽出し、
# depends-on に宣言されていない+実在するパスを検出
# JSON 配列: [{"doc":"path","mentioned":"path","line":N}]
check_undeclared_deps() {
  local repo_root="$1"
  local results=""
  local first=true

  while IFS= read -r md_file; do
    local deps
    deps=$(parse_depends_on "$md_file")
    local rel_doc
    rel_doc=$(_relpath "$md_file" "$repo_root")

    # 本文からバッククォート内のファイルパスっぽいものを抽出（サブシェル回避）
    local awk_output
    awk_output=$(awk '
      BEGIN { in_fm=0 }
      NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
      in_fm && /^---[[:space:]]*$/ { in_fm=0; next }
      !in_fm {
        line = $0
        while (match(line, /`([^`]+)`/)) {
          tick_start = RSTART
          tick_len = RLENGTH
          content = substr(line, tick_start + 1, tick_len - 2)
          # ファイルパスっぽいもの (src/, lib/, config/, scripts/, docs/ 等で始まり拡張子を持つ)
          if (content ~ /^(src|lib|config|scripts|docs|test|tests|spec|app|pkg|internal|cmd)\/.*\.[a-zA-Z0-9]+$/) {
            print NR "\t" content
          }
          line = substr(line, tick_start + tick_len)
        }
      }
    ' "$md_file")

    [[ -z "$awk_output" ]] && continue

    while IFS=$'\t' read -r lineno mentioned; do
      [[ -z "$mentioned" ]] && continue

      # 実在するか確認
      [[ ! -e "${repo_root}/${mentioned}" ]] && continue

      # depends-on で既に宣言済みか確認（exact match または glob match）
      local declared=false
      if [[ -n "$deps" ]]; then
        while IFS= read -r dep; do
          [[ -z "$dep" ]] && continue
          if [[ "$dep" == "$mentioned" ]]; then
            declared=true
            break
          fi
          # glob パターンの場合
          if [[ "$dep" == *'*'* ]] || [[ "$dep" == *'?'* ]]; then
            if match_glob "$dep" "$mentioned"; then
              declared=true
              break
            fi
          fi
        done <<< "$deps"
      fi

      if [[ "$declared" == false ]]; then
        [[ "$first" == true ]] && first=false || results="${results},"
        results="${results}{\"doc\":\"$(_json_escape "$rel_doc")\",\"mentioned\":\"$(_json_escape "$mentioned")\",\"line\":${lineno}}"
      fi
    done <<< "$awk_output"
  done < <(find "$repo_root" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)

  printf '[%s]' "$results"
}

# --- 4. check_orphaned_docs ---
# 他の md からリンクされておらず depends-on も持たない md を検出
# JSON 配列: ["path1","path2"]
check_orphaned_docs() {
  local repo_root="$1"

  # 全 md ファイルを収集
  local all_docs=()
  while IFS= read -r md_file; do
    local rel
    rel=$(_relpath "$md_file" "$repo_root")
    all_docs+=("$rel")
  done < <(find "$repo_root" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)

  # depends-on を持つドキュメントを記録
  local docs_with_deps=()
  for doc in "${all_docs[@]}"; do
    local deps
    deps=$(parse_depends_on "${repo_root}/${doc}")
    if [[ -n "$deps" ]]; then
      docs_with_deps+=("$doc")
    fi
  done

  # 全 md からのリンク先を収集
  local linked_docs=()
  for doc in "${all_docs[@]}"; do
    local links
    links=$(extract_md_links "${repo_root}/${doc}" "$repo_root" 2>/dev/null || true)
    if [[ -n "$links" ]]; then
      while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        linked_docs+=("$link")
      done <<< "$links"
    fi
  done

  # orphaned = depends-on なし AND どこからもリンクされていない
  local results=""
  local first=true
  for doc in "${all_docs[@]}"; do
    # depends-on を持っている場合はスキップ
    local has_deps=false
    for d in "${docs_with_deps[@]+"${docs_with_deps[@]}"}"; do
      if [[ "$d" == "$doc" ]]; then
        has_deps=true
        break
      fi
    done
    [[ "$has_deps" == true ]] && continue

    # 他のドキュメントからリンクされている場合はスキップ
    local is_linked=false
    for l in "${linked_docs[@]+"${linked_docs[@]}"}"; do
      if [[ "$l" == "$doc" ]]; then
        is_linked=true
        break
      fi
    done
    [[ "$is_linked" == true ]] && continue

    # orphaned
    [[ "$first" == true ]] && first=false || results="${results},"
    results="${results}\"$(_json_escape "$doc")\""
  done

  printf '[%s]' "$results"
}

# --- 5. check_stale_signals ---
# ドキュメント最終更新日と depends-on 先の最終更新日を比較し、
# 乖離が threshold_days 以上のものを検出
# JSON 配列: [{"doc":"path","doc_updated":"YYYY-MM-DD","dep_updated":"YYYY-MM-DD","drift_days":N}]
check_stale_signals() {
  local repo_root="$1"
  local threshold_days="${2:-90}"
  local results=""
  local first=true

  # git が利用可能か確認
  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    printf '[]'
    return 0
  fi

  while IFS= read -r md_file; do
    local deps
    deps=$(parse_depends_on "$md_file")
    [[ -z "$deps" ]] && continue

    local rel_doc
    rel_doc=$(_relpath "$md_file" "$repo_root")

    # ドキュメントの最終更新日（git log）
    local doc_date
    doc_date=$(git -C "$repo_root" log -1 --format='%at' -- "$rel_doc" 2>/dev/null)
    [[ -z "$doc_date" ]] && continue

    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue
      # glob パターンはスキップ（具体ファイルのみ対象）
      [[ "$dep" == *'*'* ]] || [[ "$dep" == *'?'* ]] && continue
      [[ ! -e "${repo_root}/${dep}" ]] && continue

      local dep_date
      dep_date=$(git -C "$repo_root" log -1 --format='%at' -- "$dep" 2>/dev/null)
      [[ -z "$dep_date" ]] && continue

      # 乖離日数を計算
      local drift_seconds drift_days_val
      if [[ "$dep_date" -gt "$doc_date" ]]; then
        drift_seconds=$((dep_date - doc_date))
      else
        continue  # dep が doc より古い場合はスキップ
      fi
      drift_days_val=$((drift_seconds / 86400))

      if [[ "$drift_days_val" -ge "$threshold_days" ]]; then
        # macOS 互換の日付フォーマット
        local doc_date_str dep_date_str
        if date -r 0 >/dev/null 2>&1; then
          # macOS
          doc_date_str=$(date -r "$doc_date" '+%Y-%m-%d')
          dep_date_str=$(date -r "$dep_date" '+%Y-%m-%d')
        else
          # Linux
          doc_date_str=$(date -d "@$doc_date" '+%Y-%m-%d')
          dep_date_str=$(date -d "@$dep_date" '+%Y-%m-%d')
        fi
        [[ "$first" == true ]] && first=false || results="${results},"
        results="${results}{\"doc\":\"$(_json_escape "$rel_doc")\",\"doc_updated\":\"${doc_date_str}\",\"dep_updated\":\"${dep_date_str}\",\"drift_days\":${drift_days_val}}"
      fi
    done <<< "$deps"
  done < <(find "$repo_root" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)

  printf '[%s]' "$results"
}

# --source-only が指定された場合は関数定義のみで終了
if [[ "${1:-}" == "--source-only" ]]; then return 0 2>/dev/null || exit 0; fi

# --- 引数パース ---
AUDIT_MODE="full"
AUDIT_RANGE=""
AUDIT_JSON=false
AUDIT_CHECK_UNDECLARED=false
AUDIT_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) AUDIT_MODE="full"; shift ;;
    --range) AUDIT_MODE="range"; AUDIT_RANGE="$2"; shift 2 ;;
    --check-undeclared) AUDIT_CHECK_UNDECLARED=true; shift ;;
    --json) AUDIT_JSON=true; shift ;;
    --root) AUDIT_ROOT="$2"; shift 2 ;;
    --source-only) exit 0 ;;
    *) echo "[doc-audit] Unknown option: $1" >&2; exit 2 ;;
  esac
done

# リポジトリルート決定
if [[ -n "$AUDIT_ROOT" ]]; then
  REPO_ROOT="$AUDIT_ROOT"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

# --- メイン処理 ---

# 対象 md ファイルの収集
target_docs=()
if [[ "$AUDIT_MODE" == "range" ]] && [[ -n "$AUDIT_RANGE" ]]; then
  while IFS= read -r f; do
    [[ "$f" == *.md ]] && target_docs+=("$f")
  done < <(git -C "$REPO_ROOT" diff --name-only "$AUDIT_RANGE" 2>/dev/null)
  # range の場合でも全 md をスキャンする（影響を受けた md だけでなく監査全体）
fi

# 全 md ファイル数をカウント
total_docs=$(find "$REPO_ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')

# チェック実行
if [[ "$AUDIT_CHECK_UNDECLARED" == true ]]; then
  undeclared=$(check_undeclared_deps "$REPO_ROOT")
  if [[ "$AUDIT_JSON" == true ]]; then
    printf '{"undeclared_deps":%s,"meta":{"total_docs_scanned":%s,"scope":"%s","commit_range":%s}}' \
      "$undeclared" "$total_docs" "$AUDIT_MODE" \
      "$(if [[ -n "$AUDIT_RANGE" ]]; then printf '"%s"' "$AUDIT_RANGE"; else printf 'null'; fi)"
  else
    echo "$undeclared"
  fi
  # exit code
  if [[ "$undeclared" != "[]" ]]; then
    exit 1
  fi
  exit 0
fi

# --full (default): 全チェック実行
broken=$(check_broken_deps "$REPO_ROOT")
dead=$(check_dead_links "$REPO_ROOT")
undeclared=$(check_undeclared_deps "$REPO_ROOT")
orphaned=$(check_orphaned_docs "$REPO_ROOT")
stale=$(check_stale_signals "$REPO_ROOT")

if [[ "$AUDIT_JSON" == true ]]; then
  printf '{"broken_deps":%s,"dead_links":%s,"undeclared_deps":%s,"orphaned_docs":%s,"stale_signals":%s,"meta":{"total_docs_scanned":%s,"scope":"%s","commit_range":%s}}' \
    "$broken" "$dead" "$undeclared" "$orphaned" "$stale" "$total_docs" "$AUDIT_MODE" \
    "$(if [[ -n "$AUDIT_RANGE" ]]; then printf '"%s"' "$AUDIT_RANGE"; else printf 'null'; fi)"
else
  echo "broken_deps: $broken"
  echo "dead_links: $dead"
  echo "undeclared_deps: $undeclared"
  echo "orphaned_docs: $orphaned"
  echo "stale_signals: $stale"
fi

# exit code: 1 if any issues found
has_issues=false
for arr in "$broken" "$dead" "$undeclared" "$orphaned" "$stale"; do
  if [[ "$arr" != "[]" ]]; then
    has_issues=true
    break
  fi
done

if [[ "$has_issues" == true ]]; then
  exit 1
fi
exit 0
