#!/bin/bash
set -euo pipefail

MESSAGE="${1:?Usage: notify.sh MESSAGE TITLE TYPE}"
TITLE="${2:?Usage: notify.sh MESSAGE TITLE TYPE}"
TYPE="${3:?Usage: notify.sh MESSAGE TITLE TYPE}"
PANE_ID="${WEZTERM_PANE:-}"
ICON="${HOME}/.dotfiles/claude/assets/claude-icon.png"

command -v alerter >/dev/null 2>&1 || {
  echo "notify.sh: alerter not found (brew install vjeantet/tap/alerter)" >&2
  exit 1
}

case "$TYPE" in
  permission|question) TIMEOUT=0 ;;
  *)                   TIMEOUT=30 ;;
esac

# バックグラウンドで alerter を実行し、クリック時に WezTerm タブへ遷移
(
  RESULT=$(alerter \
    --message "$MESSAGE" \
    --title "$TITLE" \
    --app-icon "$ICON" \
    --timeout "$TIMEOUT" \
    --group "claude-${PANE_ID:-default}" \
    --sound default \
    2>/dev/null) || true

  case "${RESULT:-}" in
    @CONTENTCLICKED|@ACTIONCLICKED)
      osascript -e 'tell application "WezTerm" to activate' 2>/dev/null || true
      if [ -n "$PANE_ID" ]; then
        wezterm cli activate-pane --pane-id "$PANE_ID" 2>/dev/null || true
      fi
      ;;
  esac
) &

# バックグラウンドプロセスをデタッチして即座に終了
disown
