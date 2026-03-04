#!/bin/bash
set -euo pipefail

MESSAGE="${1:?Usage: notify.sh MESSAGE TITLE TYPE}"
TITLE="${2:?Usage: notify.sh MESSAGE TITLE TYPE}"
TYPE="${3:?Usage: notify.sh MESSAGE TITLE TYPE}"

# タイプ別アイコンとタイムアウト
case "$TYPE" in
  idle)       ICON="✅"; TIMEOUT=5000 ;;
  permission) ICON="🔐"; TIMEOUT=0    ;;
  question)   ICON="💬"; TIMEOUT=0    ;;
  *)          ICON="📢"; TIMEOUT=5000 ;;
esac

DISPLAY_TITLE="${ICON} ${TITLE}"

# WezTerm の user-var エスケープシーケンスで toast_notification をトリガー
VALUE="$(printf '%s\t%s\t%s' "$DISPLAY_TITLE" "$MESSAGE" "$TIMEOUT")"
ENCODED="$(printf '%s' "$VALUE" | base64)"
ESCAPE_SEQ="$(printf "\033]1337;SetUserVar=%s=%s\007" "claude_notify" "$ENCODED")"

if (printf '%s' "$ESCAPE_SEQ" > /dev/tty) 2>/dev/null; then
  : # WezTerm toast_notification に送信成功
else
  # TTY が使えない場合は osascript にフォールバック
  osascript -e "display notification \"$MESSAGE\" with title \"$DISPLAY_TITLE\""
fi
