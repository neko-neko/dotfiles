#!/usr/bin/env bash
#
# drop-upload action — keybind (plugin_action) 発火時に実行される。
# 責務は「文脈の凍結」と overlay の起動のみ:
# overlay が開くとフォーカスが移り対象ペイン情報が取れなくなるため、
# 発火時点の focused pane と process-info を STATE_DIR に保存してから overlay を開く。
set -euo pipefail

if [[ "${HERDR_ENV:-}" != "1" ]]; then
  echo "drop-upload: must run inside herdr" >&2
  exit 1
fi

state_dir="${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR is not set}"

pane_id=""
if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]]; then
  pane_id=$(jq -r '.focused_pane_id // empty' <<<"$HERDR_PLUGIN_CONTEXT_JSON")
fi
if [[ -z "$pane_id" ]]; then
  pane_id=$(herdr pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty') || pane_id=""
fi

printf '%s\n' "$pane_id" > "$state_dir/target_pane"

if [[ -n "$pane_id" ]]; then
  herdr pane process-info --pane "$pane_id" > "$state_dir/process_info.json" 2>/dev/null \
    || : > "$state_dir/process_info.json"
else
  : > "$state_dir/process_info.json"
fi

herdr plugin pane open --plugin drop-upload --entrypoint dropzone --placement overlay --focus
