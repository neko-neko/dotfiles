#!/bin/bash
set -euo pipefail

MESSAGE="${1:?Usage: notify.sh MESSAGE TITLE TYPE}"
TITLE="${2:?Usage: notify.sh MESSAGE TITLE TYPE}"
TYPE="${3:?Usage: notify.sh MESSAGE TITLE TYPE}"

case "$TYPE" in
  permission|question) TIMEOUT=0    ;;
  *)                   TIMEOUT=4000 ;;
esac

# WezTerm の user-var エスケープシーケンスで toast_notification をトリガー
VALUE="$(printf '%s\t%s\t%s' "$TITLE" "$MESSAGE" "$TIMEOUT")"
ENCODED="$(printf '%s' "$VALUE" | base64)"
ESCAPE_SEQ="$(printf "\033]1337;SetUserVar=%s=%s\007" "claude_notify" "$ENCODED")"

if (printf '%s' "$ESCAPE_SEQ" > /dev/tty) 2>/dev/null; then
  : # WezTerm toast_notification に送信成功
else
  # TTY が使えない場合は osascript にフォールバック
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
fi
