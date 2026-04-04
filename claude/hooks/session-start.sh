#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../skills/handover/scripts/handover-lib.sh"

# プロジェクトルートを取得
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

HANDOVER_BASE="${PROJECT_DIR}/.agents/handover"

# handover ディレクトリがなければ何もしない
[[ -d "$HANDOVER_BASE" ]] || exit 0

# アクティブセッションをスキャン
SESSIONS="$(scan_sessions "$HANDOVER_BASE")"
SESSION_COUNT="$(echo "$SESSIONS" | jq 'length')"

if [[ "$SESSION_COUNT" -eq 0 ]]; then
  exit 0
fi

# READY セッション情報を出力
echo "📋 Handover sessions found:"
echo "$SESSIONS" | jq -r '.[] | "  - [\(.branch)/\(.fingerprint)] tasks: \(.done_tasks)/\(.total_tasks) | next: \(.next_action)"'
echo ""
echo "Use '/continue' to resume, or start fresh."
