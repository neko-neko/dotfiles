#!/usr/bin/env bash
# trace-lib.sh — Observability trace recording library
# Source this file from skill orchestrators to record pipeline events.
#
# Usage:
#   source trace-lib.sh
#   TRACE_SESSION_ID="session-123"
#   trace_file=$(_trace_resolve_path "/path/to/handover/dir")
#   trace_phase_start "$trace_file" "feature-dev" 1 "Design"

# ---- Constants ----
readonly TRACE_FILENAME="trace.jsonl"

# ---- Internal functions ----

_trace_log() {
  local prefix="${TRACE_LOG_PREFIX:-[trace-lib]}"
  echo "${prefix} $*" >&2
}

# Resolve trace file path from handover directory
_trace_resolve_path() {
  local handover_dir="$1"
  echo "${handover_dir}/${TRACE_FILENAME}"
}

# Write a single JSONL event line (append)
_trace_write() {
  local trace_file="$1"
  local event="$2"
  local data_json="$3"
  local session_id="${TRACE_SESSION_ID:-unknown}"

  # Graceful no-op if parent directory doesn't exist
  local dir
  dir="$(dirname "$trace_file")"
  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  printf '%s\n' "{\"ts\":\"${ts}\",\"session_id\":\"${session_id}\",\"event\":\"${event}\",\"data\":${data_json}}" \
    >> "${trace_file}"
}

# ---- Public functions ----

# Tier 2: Phase start
trace_phase_start() {
  local trace_file="$1" pipeline="$2" phase="$3" phase_name="$4"
  _trace_write "$trace_file" "phase_start" \
    "{\"pipeline\":\"${pipeline}\",\"phase\":${phase},\"phase_name\":\"${phase_name}\"}"
}

# Tier 2: Phase end
trace_phase_end() {
  local trace_file="$1" pipeline="$2" phase="$3" phase_name="$4" duration_ms="$5"
  _trace_write "$trace_file" "phase_end" \
    "{\"pipeline\":\"${pipeline}\",\"phase\":${phase},\"phase_name\":\"${phase_name}\",\"duration_ms\":${duration_ms}}"
}

# Tier 3: Agent start
trace_agent_start() {
  local trace_file="$1" pipeline="$2" agent="$3" phase="$4"
  _trace_write "$trace_file" "agent_start" \
    "{\"pipeline\":\"${pipeline}\",\"agent\":\"${agent}\",\"phase\":${phase}}"
}

# Tier 3: Agent end
trace_agent_end() {
  local trace_file="$1" pipeline="$2" agent="$3" phase="$4" \
        duration_ms="$5" findings_count="$6" parse_method="$7"
  _trace_write "$trace_file" "agent_end" \
    "{\"pipeline\":\"${pipeline}\",\"agent\":\"${agent}\",\"phase\":${phase},\"duration_ms\":${duration_ms},\"findings_count\":${findings_count},\"parse_method\":\"${parse_method}\"}"
}

# Tier 1: User decision with findings snapshot
trace_user_decision() {
  local trace_file="$1" pipeline="$2" total="$3" \
        selected_json="$4" rejected_json="$5" snapshot_json="$6"
  _trace_write "$trace_file" "user_decision" \
    "{\"pipeline\":\"${pipeline}\",\"total_findings\":${total},\"selected\":${selected_json},\"rejected\":${rejected_json},\"findings_snapshot\":${snapshot_json}}"
}

# Tier 2: Retry
trace_retry() {
  local trace_file="$1" pipeline="$2" phase="$3" attempt="$4" reason="$5"
  _trace_write "$trace_file" "retry" \
    "{\"pipeline\":\"${pipeline}\",\"phase\":${phase},\"attempt\":${attempt},\"reason\":\"${reason}\"}"
}

# Tier 3: Error
trace_error() {
  local trace_file="$1" pipeline="$2" agent="$3" error_type="$4" message="$5"
  local safe_message
  safe_message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 500)
  _trace_write "$trace_file" "error" \
    "{\"pipeline\":\"${pipeline}\",\"agent\":\"${agent}\",\"error_type\":\"${error_type}\",\"message\":\"${safe_message}\"}"
}

# Tier 2: Handover event
trace_handover() {
  local trace_file="$1" pipeline="$2" phase="$3" reason="$4"
  _trace_write "$trace_file" "handover" \
    "{\"pipeline\":\"${pipeline}\",\"phase\":${phase},\"reason\":\"${reason}\"}"
}
