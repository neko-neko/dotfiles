#!/bin/bash
set -euo pipefail

readonly HANDOVER_LOG_PREFIX="[claude-handover]"
readonly MAX_MARKDOWN_BYTES=102400  # 100KB
readonly MIN_JSONL_LINES=10

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/handover-lib.sh"

log() {
  echo "${HANDOVER_LOG_PREFIX} $*" >&2
}

die() {
  log "ERROR: $*"
  exit 0  # hooks をブロックしない
}

# ---------------------------------------------------------------------------
# 引数
# ---------------------------------------------------------------------------
TRIGGER="${1:-}"
if [[ -z "$TRIGGER" ]]; then
  die "usage: claude-handover <pre-compact|session-end>"
fi
if [[ "$TRIGGER" != "pre-compact" && "$TRIGGER" != "session-end" ]]; then
  die "unknown trigger: ${TRIGGER}"
fi

# ---------------------------------------------------------------------------
# 1. stdin から JSON を読み取り
# ---------------------------------------------------------------------------
STDIN_JSON="$(cat)"
if [[ -z "$STDIN_JSON" ]]; then
  die "no JSON received on stdin"
fi

SESSION_ID="$(echo "$STDIN_JSON" | jq -r '.session_id // empty')"
TRANSCRIPT_PATH="$(echo "$STDIN_JSON" | jq -r '.transcript_path // empty')"

if [[ -z "$SESSION_ID" ]]; then
  die "session_id not found in stdin JSON"
fi
if [[ -z "$TRANSCRIPT_PATH" ]]; then
  die "transcript_path not found in stdin JSON"
fi

# ---------------------------------------------------------------------------
# 2. Guard clauses
# ---------------------------------------------------------------------------
if [[ -z "${CLAUDE_PROJECT_DIR:-}" ]]; then
  die "CLAUDE_PROJECT_DIR is not set"
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  die "transcript file does not exist: ${TRANSCRIPT_PATH}"
fi

LINE_COUNT="$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')"
if [[ "$LINE_COUNT" -lt "$MIN_JSONL_LINES" ]]; then
  log "transcript too short (${LINE_COUNT} lines < ${MIN_JSONL_LINES}), skipping"
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Setup paths (branch/fingerprint structure)
# ---------------------------------------------------------------------------
SESSION_DIR="$(resolve_handover_dir)"
STATE_FILE="${SESSION_DIR}/project-state.json"
HANDOVER_PATH="${SESSION_DIR}/handover.md"

# ---------------------------------------------------------------------------
# 4. session-end: check if state has changed (skip if unchanged)
# ---------------------------------------------------------------------------
if [[ "$TRIGGER" == "session-end" && -f "$STATE_FILE" ]]; then
  if ! has_state_changed "$STATE_FILE"; then
    log "project-state.json unchanged since session start, skipping update"
    # Still proceed to MEMORY.md update and session spawn
    # but skip the expensive transcript processing
    goto_session_end_tasks=true
  fi
fi

if [[ "${goto_session_end_tasks:-false}" != "true" ]]; then

# ---------------------------------------------------------------------------
# 5. JSONL を軽量 Markdown に変換 (BUG FIX: .message が null のケースに対応)
# ---------------------------------------------------------------------------
read -r -d '' JQ_FILTER << 'JQEOF' || true
select(.type == "user" or .type == "assistant") |
select(.message != null) |
if .type == "user" then
  (if (.message.content | type) == "string" then .message.content
   elif (.message.content | type) == "array" then (.message.content | map(select(.type == "text") | .text) | join("\n"))
   else "" end) as $text |
  if ($text | length) > 0 then
    "## User\n" + $text + "\n"
  else empty end
elif .type == "assistant" then
  (if (.message.content | type) == "string" then .message.content
   elif (.message.content | type) == "array" then (.message.content | map(select(.type == "text") | .text) | join("\n"))
   else "" end) as $text |
  (if (.message.content | type) == "array" then
     (.message.content | map(select(.type == "thinking") | .thinking) | join("\n"))
   else "" end) as $thinking |
  (
    if ($text | length) > 0 then "## Assistant\n" + $text + "\n" else "" end
  ) + (
    if ($thinking | length) > 0 then "## Thinking\n" + $thinking + "\n" else "" end
  ) |
  if (. | length) > 0 then . else empty end
else empty end
JQEOF

CONVERTED_LOG="$(jq -r "$JQ_FILTER" "$TRANSCRIPT_PATH" 2>/dev/null)" || die "jq failed to parse transcript"

if [[ -z "$CONVERTED_LOG" ]]; then
  die "converted log is empty"
fi

# 100KB 超の場合は末尾から切り出し
BYTE_SIZE="${#CONVERTED_LOG}"
if [[ "$BYTE_SIZE" -gt "$MAX_MARKDOWN_BYTES" ]]; then
  log "converted log too large (${BYTE_SIZE} bytes), truncating to last ${MAX_MARKDOWN_BYTES} bytes"
  CONVERTED_LOG="${CONVERTED_LOG: -$MAX_MARKDOWN_BYTES}"
fi

# ---------------------------------------------------------------------------
# 6. claude -p で project-state.json 生成
# ---------------------------------------------------------------------------
CURRENT_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# 既存の project-state.json があればマージ用に読み込む
EXISTING_STATE=""
if [[ -f "$STATE_FILE" ]] && validate_project_state "$STATE_FILE" 2>/dev/null; then
  EXISTING_STATE="$(cat "$STATE_FILE")"
fi

read -r -d '' SUMMARY_PROMPT << PROMPTEOF || true
以下はClaude Codeセッションのチャットログです。このセッションの内容をproject-state.json形式で出力してください。

出力は以下のJSONスキーマに厳密に従うこと（JSONのみ出力、他のテキストは不要）:

{
  "version": 2,
  "generated_at": "${CURRENT_TIME}",
  "session_id": "${SESSION_ID}",
  "status": "READY または ALL_COMPLETE",
  "active_tasks": [
    {
      "id": "T1",
      "description": "タスクの説明",
      "status": "done | in_progress | blocked",
      "commit_sha": "コミットSHA（done の場合のみ、不明なら null）",
      "file_paths": ["関連ファイルパス"],
      "next_action": "次の具体的アクション（in_progress/blocked の場合）",
      "blockers": ["ブロッカー（blocked の場合）"],
      "last_touched": "${CURRENT_TIME}"
    }
  ],
  "recent_decisions": [
    {
      "decision": "決定事項",
      "rationale": "理由",
      "date": "${CURRENT_TIME}"
    }
  ],
  "architecture_changes": [],
  "known_issues": [
    {
      "description": "既知の問題",
      "severity": "high | medium | low",
      "related_files": ["関連ファイル"]
    }
  ],
  "session_hash": ""
}

ルール:
- active_tasks の全 status が "done" なら、トップレベルの status を "ALL_COMPLETE" にする
- チャットログの事実のみ記述し、推測しない
- architecture_changes は空配列にする（post-commit hook が管理する）
- 日本語で記述
PROMPTEOF

# 既存 state がある場合はマージ指示を追加
USER_PROMPT="$CONVERTED_LOG"
if [[ -n "$EXISTING_STATE" ]]; then
  read -r -d '' MERGE_INSTRUCTION << 'MERGEEOF' || true

--- 以下は既存の project-state.json です。マージルール: ---
- active_tasks: 同じ ID のタスクは最新の情報で上書き、新しいタスクは追加
- recent_decisions: 重複しない決定事項を追記
- architecture_changes: 既存のものをそのまま保持（変更しない）
- known_issues: 解決済みなら削除、新規は追加

既存の project-state.json:
MERGEEOF
  USER_PROMPT="${CONVERTED_LOG}

${MERGE_INSTRUCTION}
${EXISTING_STATE}"
fi

log "generating project-state.json via claude -p (trigger=${TRIGGER})..."
GENERATED_JSON="$(echo "$USER_PROMPT" | claude -p --model sonnet --system-prompt "$SUMMARY_PROMPT" 2>/dev/null)" || die "claude -p failed for JSON generation"

if [[ -z "$GENERATED_JSON" ]]; then
  die "generated JSON is empty"
fi

# JSON から余計なテキストを除去（```json ... ``` でラップされている場合）
GENERATED_JSON="$(echo "$GENERATED_JSON" | sed -n '/^[{]/,/^[}]/p')"

# JSON バリデーション
if ! echo "$GENERATED_JSON" | jq empty 2>/dev/null; then
  die "generated output is not valid JSON"
fi

# architecture_changes を既存のものとマージ
if [[ -n "$EXISTING_STATE" ]]; then
  EXISTING_ARCH="$(echo "$EXISTING_STATE" | jq '.architecture_changes // []')"
  GENERATED_JSON="$(echo "$GENERATED_JSON" | jq --argjson arch "$EXISTING_ARCH" '.architecture_changes = $arch')"
fi

# ---------------------------------------------------------------------------
# 7. project-state.json 書き出し
# ---------------------------------------------------------------------------
echo "$GENERATED_JSON" > "$STATE_FILE"

# status を再計算
update_status_field "$STATE_FILE"

# session_hash を保存
store_session_hash "$STATE_FILE"

log "project-state.json written to ${STATE_FILE}"

# ---------------------------------------------------------------------------
# 8. handover.md ビュー生成
# ---------------------------------------------------------------------------
generate_handover_md "$STATE_FILE" "$HANDOVER_PATH"
log "handover.md written to ${HANDOVER_PATH}"

fi  # end of goto_session_end_tasks check

# ---------------------------------------------------------------------------
# 9. (session-end のみ) MEMORY.md 更新
# ---------------------------------------------------------------------------
if [[ "$TRIGGER" == "session-end" ]]; then
  # BUG FIX: MEMORY.md パスを既存ディレクトリから検出
  MEMORY_DIR="$(find_memory_dir "$CLAUDE_PROJECT_DIR")"

  if [[ -z "$MEMORY_DIR" ]]; then
    # フォールバック: 従来のエンコーディング
    ENCODED_PATH="${CLAUDE_PROJECT_DIR//[\/.]/-}"
    ENCODED_PATH="${ENCODED_PATH#-}"
    MEMORY_DIR="${HOME}/.claude/projects/${ENCODED_PATH}/memory"
  fi

  MEMORY_PATH="${MEMORY_DIR}/MEMORY.md"

  EXISTING_MEMORY=""
  if [[ -f "$MEMORY_PATH" ]]; then
    EXISTING_MEMORY="$(cat "$MEMORY_PATH")"
  fi

  # handover.md を MEMORY.md 更新のソースとして使用
  HANDOVER_CONTENT=""
  if [[ -f "$HANDOVER_PATH" ]]; then
    HANDOVER_CONTENT="$(cat "$HANDOVER_PATH")"
  fi

  if [[ -n "$HANDOVER_CONTENT" ]]; then
    read -r -d '' MEMORY_SYSTEM_PROMPT << 'MSEOF' || true
あなたはプロジェクト横断で再利用可能な知見を抽出するアシスタントです。

以下のルールに従ってください:
- セッションのハンドオーバー文書から、他のプロジェクトや将来のセッションでも役立つ汎用的な知見・パターン・注意点のみを抽出
- プロジェクト固有の詳細（具体的なファイルパス、タスクの進捗など）は含めない
- 既存の MEMORY.md の内容と重複する知見は出力しない
- 新しい知見がなければ「追記なし」とだけ出力
- 出力は箇条書きの Markdown 形式
- 日本語で出力
MSEOF

    MEMORY_USER_PROMPT="## 既存の MEMORY.md
${EXISTING_MEMORY:-（なし）}

## 今回のハンドオーバー文書
${HANDOVER_CONTENT}"

    log "extracting reusable knowledge for MEMORY.md..."
    MEMORY_ADDITION="$(echo "$MEMORY_USER_PROMPT" | claude -p --model sonnet --system-prompt "$MEMORY_SYSTEM_PROMPT" 2>/dev/null)" || {
      log "WARNING: claude -p failed for MEMORY.md update, skipping"
      MEMORY_ADDITION=""
    }

    if [[ -n "$MEMORY_ADDITION" && "$MEMORY_ADDITION" != "追記なし" ]]; then
      mkdir -p "$MEMORY_DIR"
      if [[ -n "$EXISTING_MEMORY" ]]; then
        printf "\n%s\n" "$MEMORY_ADDITION" >> "$MEMORY_PATH"
      else
        echo "$MEMORY_ADDITION" > "$MEMORY_PATH"
      fi
      log "MEMORY.md updated at ${MEMORY_PATH}"
    else
      log "no new knowledge to add to MEMORY.md"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 10. (session-end のみ) WezTerm 新セッション起動
  # ---------------------------------------------------------------------------
  if command -v wezterm &>/dev/null && [[ -f "$HANDOVER_PATH" ]]; then
    log "spawning new Claude session in WezTerm..."
    wezterm cli spawn --cwd "$CLAUDE_PROJECT_DIR" -- bash -c "claude -r \"${SESSION_ID}\"" 2>/dev/null || {
      log "WARNING: wezterm cli spawn failed"
    }
  else
    if ! command -v wezterm &>/dev/null; then
      log "wezterm cli not available, skipping session spawn"
    else
      log "handover.md not found, skipping session spawn"
    fi
  fi
fi

log "done (trigger=${TRIGGER})"
