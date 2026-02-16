#!/bin/bash
set -euo pipefail

readonly HANDOVER_LOG_PREFIX="[claude-post-commit]"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"

# 1. Determine project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [[ -z "$PROJECT_DIR" ]]; then
  _handover_log "not in a git repository, skipping"
  exit 0
fi

# 2. Find active handover session (branch/fingerprint structure)
SESSION_DIR="$(find_active_session_dir "$PROJECT_DIR")" || {
  _handover_log "no active handover session found, skipping"
  exit 0
}

STATE_FILE="${SESSION_DIR}/project-state.json"
HANDOVER_FILE="${SESSION_DIR}/handover.md"

if ! validate_project_state "$STATE_FILE"; then
  _handover_log "invalid project-state.json, skipping"
  exit 0
fi

# 3. Get latest commit info
COMMIT_SHA="$(git -C "$PROJECT_DIR" log -1 --format='%H' 2>/dev/null)" || {
  _handover_log "failed to get commit SHA"
  exit 0
}
COMMIT_SHORT="$(echo "$COMMIT_SHA" | cut -c1-7)"
COMMIT_MSG="$(git -C "$PROJECT_DIR" log -1 --format='%s' 2>/dev/null)" || true

# 4. Get changed files
# Handle first commit case (no HEAD~1)
if git -C "$PROJECT_DIR" rev-parse HEAD~1 &>/dev/null; then
  DIFF_STAT="$(git -C "$PROJECT_DIR" diff --stat HEAD~1..HEAD 2>/dev/null)" || true
  FILES_CHANGED_RAW="$(git -C "$PROJECT_DIR" diff --name-only HEAD~1..HEAD 2>/dev/null)" || true
else
  DIFF_STAT="$(git -C "$PROJECT_DIR" diff --stat HEAD 2>/dev/null)" || true
  FILES_CHANGED_RAW="$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null)" || true
fi

# Convert to JSON array
FILES_CHANGED_JSON="$(echo "$FILES_CHANGED_RAW" | jq -R -s '[split("\n")[] | select(length > 0)]')"

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# 5. Generate summary via claude -p --model sonnet
SUMMARY_INPUT="Commit: ${COMMIT_SHORT} ${COMMIT_MSG}
${DIFF_STAT}"

SUMMARY="$(echo "$SUMMARY_INPUT" | claude -p --model sonnet --system-prompt "以下のgitコミット情報を日本語で1-2行に要約してください。技術的に正確に、変更の目的を簡潔に述べてください。" 2>/dev/null)" || {
  _handover_log "WARNING: claude -p failed, using commit message as summary"
  SUMMARY="$COMMIT_MSG"
}

if [[ -z "$SUMMARY" ]]; then
  SUMMARY="$COMMIT_MSG"
fi

# 6. Update project-state.json
add_architecture_change "$STATE_FILE" "$COMMIT_SHORT" "$SUMMARY" "$FILES_CHANGED_JSON" "$NOW"
touch_related_tasks "$STATE_FILE" "$FILES_CHANGED_JSON" "$NOW"
update_status_field "$STATE_FILE"
store_session_hash "$STATE_FILE"

# 7. Regenerate handover.md
generate_handover_md "$STATE_FILE" "$HANDOVER_FILE"

_handover_log "updated project-state.json and handover.md for commit ${COMMIT_SHORT}"
