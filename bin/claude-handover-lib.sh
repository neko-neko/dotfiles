#!/bin/bash
# claude-handover-lib.sh — shared utility functions for handover
# Source this file from claude-handover and claude-post-commit

readonly HANDOVER_LIB_VERSION=2
readonly MAX_ARCHITECTURE_CHANGES=10
readonly STALE_THRESHOLD_HOURS=48

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_handover_log() {
  local prefix="${HANDOVER_LOG_PREFIX:-[handover-lib]}"
  echo "${prefix} $*" >&2
}

# ---------------------------------------------------------------------------
# JSON validation
# ---------------------------------------------------------------------------

# Validate project-state.json structure
# Returns 0 if valid, 1 if invalid (with error message on stderr)
validate_project_state() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    _handover_log "ERROR: file not found: ${json_file}"
    return 1
  fi

  # Syntax check
  if ! jq empty "$json_file" 2>/dev/null; then
    _handover_log "ERROR: invalid JSON syntax in ${json_file}"
    return 1
  fi

  # Required fields check
  local missing
  missing="$(jq -r '
    [
      (if .version == null then "version" else empty end),
      (if .status == null then "status" else empty end),
      (if .active_tasks == null then "active_tasks" else empty end)
    ] | join(", ")
  ' "$json_file")"

  if [[ -n "$missing" ]]; then
    _handover_log "ERROR: missing required fields: ${missing}"
    return 1
  fi

  # Version check
  local version
  version="$(jq -r '.version' "$json_file")"
  if [[ "$version" != "2" ]]; then
    _handover_log "ERROR: unsupported version: ${version} (expected 2)"
    return 1
  fi

  # Status enum check
  local status
  status="$(jq -r '.status' "$json_file")"
  if [[ "$status" != "READY" && "$status" != "ALL_COMPLETE" ]]; then
    _handover_log "ERROR: invalid status: ${status} (expected READY or ALL_COMPLETE)"
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Status auto-detection
# ---------------------------------------------------------------------------

# Determine status based on active_tasks
# Reads JSON from stdin, outputs "ALL_COMPLETE" or "READY"
compute_status() {
  jq -r '
    if (.active_tasks | length) == 0 then "ALL_COMPLETE"
    elif (.active_tasks | all(.status == "done")) then "ALL_COMPLETE"
    else "READY"
    end
  '
}

# ---------------------------------------------------------------------------
# Architecture changes management
# ---------------------------------------------------------------------------

# Add an architecture change entry and trim to MAX_ARCHITECTURE_CHANGES
# Usage: add_architecture_change <json_file> <commit_sha> <summary> <files_changed_json_array> <date>
add_architecture_change() {
  local json_file="$1"
  local commit_sha="$2"
  local summary="$3"
  local files_changed="$4"  # JSON array string, e.g. '["file1","file2"]'
  local date="$5"
  local max=$MAX_ARCHITECTURE_CHANGES

  local tmp
  tmp="$(mktemp)"

  jq --arg sha "$commit_sha" \
     --arg sum "$summary" \
     --argjson files "$files_changed" \
     --arg dt "$date" \
     --argjson max "$max" \
     '
     .architecture_changes = (
       (.architecture_changes // []) + [{
         commit_sha: $sha,
         summary: $sum,
         files_changed: $files,
         date: $dt
       }]
     ) |
     .architecture_changes = (.architecture_changes | .[-$max:])
     ' "$json_file" > "$tmp" && mv "$tmp" "$json_file"
}

# ---------------------------------------------------------------------------
# active_tasks helpers
# ---------------------------------------------------------------------------

# Update last_touched for tasks whose file_paths overlap with changed files
# Usage: touch_related_tasks <json_file> <files_changed_json_array> <timestamp>
touch_related_tasks() {
  local json_file="$1"
  local files_changed="$2"  # JSON array string
  local timestamp="$3"

  local tmp
  tmp="$(mktemp)"

  jq --argjson changed "$files_changed" \
     --arg ts "$timestamp" \
     '
     .active_tasks = [
       .active_tasks[] |
       if (.file_paths // []) as $fp |
          ($changed | any(. as $c | $fp | any(. == $c)))
       then .last_touched = $ts
       else .
       end
     ]
     ' "$json_file" > "$tmp" && mv "$tmp" "$json_file"
}

# ---------------------------------------------------------------------------
# Handover.md view generation
# ---------------------------------------------------------------------------

# Generate handover.md from project-state.json
# Usage: generate_handover_md <json_file> <output_file>
generate_handover_md() {
  local json_file="$1"
  local output_file="$2"

  if ! validate_project_state "$json_file"; then
    _handover_log "ERROR: cannot generate handover.md from invalid JSON"
    return 1
  fi

  jq -r '
    def format_task:
      if .status == "done" then
        "- [\(.id)] \(.description) (\(.commit_sha // "no-sha"))"
      elif .status == "in_progress" then
        "- [\(.id)] **in_progress** \(.description)\n  - files: \((.file_paths // []) | join(", "))\n  - next: \(.next_action // "未定義")"
      elif .status == "blocked" then
        "- [\(.id)] **blocked** \(.description)\n  - files: \((.file_paths // []) | join(", "))\n  - next: \(.next_action // "未定義")\n  - blocker: \((.blockers // []) | join(", "))"
      else
        "- [\(.id)] **\(.status)** \(.description)"
      end;

    "# Session Handover",
    "> Generated: \(.generated_at)",
    "> Session: \(.session_id // "unknown")",
    "> Status: \(.status)",
    "",
    "## Completed",
    (if ([.active_tasks[] | select(.status == "done")] | length) > 0
     then [.active_tasks[] | select(.status == "done") | format_task] | join("\n")
     else "- なし" end),
    "",
    "## Remaining",
    (if ([.active_tasks[] | select(.status != "done")] | length) > 0
     then [.active_tasks[] | select(.status != "done") | format_task] | join("\n")
     else "- なし" end),
    "",
    "## Blockers",
    (if ([.active_tasks[] | select(.blockers != null and (.blockers | length) > 0)] | length) > 0
     then [.active_tasks[] | select(.blockers != null and (.blockers | length) > 0) |
       "- [\(.id)] \((.blockers // []) | join(", "))"] | join("\n")
     else "- なし" end),
    "",
    "## Context",
    (if (.recent_decisions // [] | length) > 0
     then [.recent_decisions[] | "- \(.decision)（理由: \(.rationale)）"] | join("\n")
     else "- なし" end),
    "",
    "## Architecture Changes (Recent)",
    (if (.architecture_changes // [] | length) > 0
     then [.architecture_changes[] | "- \(.commit_sha): \(.summary)"] | join("\n")
     else "- なし" end),
    "",
    "## Known Issues",
    (if (.known_issues // [] | length) > 0
     then [.known_issues[] | "- [\(.severity)] \(.description)"] | join("\n")
     else "- なし" end)
  ' "$json_file" > "$output_file"
}

# ---------------------------------------------------------------------------
# Session hash
# ---------------------------------------------------------------------------

# Compute SHA256 hash of project-state.json (excluding session_hash field)
# Usage: compute_session_hash <json_file>
compute_session_hash() {
  local json_file="$1"
  jq -S 'del(.session_hash)' "$json_file" | shasum -a 256 | cut -d' ' -f1
}

# Store session hash into the JSON
# Usage: store_session_hash <json_file>
store_session_hash() {
  local json_file="$1"
  local hash
  hash="$(compute_session_hash "$json_file")"

  local tmp
  tmp="$(mktemp)"
  jq --arg h "$hash" '.session_hash = $h' "$json_file" > "$tmp" && mv "$tmp" "$json_file"
}

# Check if project state has changed since last stored hash
# Returns 0 if changed, 1 if unchanged
has_state_changed() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    return 0  # no file = consider changed (needs creation)
  fi

  local stored_hash current_hash
  stored_hash="$(jq -r '.session_hash // ""' "$json_file")"
  current_hash="$(compute_session_hash "$json_file")"

  if [[ -z "$stored_hash" || "$stored_hash" != "$current_hash" ]]; then
    return 0  # changed
  else
    return 1  # unchanged
  fi
}

# ---------------------------------------------------------------------------
# Auto-update status field
# ---------------------------------------------------------------------------

# Recalculate and set the top-level status field based on active_tasks
# Usage: update_status_field <json_file>
update_status_field() {
  local json_file="$1"
  local new_status
  new_status="$(cat "$json_file" | compute_status)"

  local tmp
  tmp="$(mktemp)"
  jq --arg s "$new_status" '.status = $s' "$json_file" > "$tmp" && mv "$tmp" "$json_file"
}

# ---------------------------------------------------------------------------
# MEMORY.md path detection
# ---------------------------------------------------------------------------

# Find the actual Claude Code projects directory for the given project path
# Claude Code encodes paths in various ways; detect from existing directories
# Usage: find_memory_dir <project_dir>
find_memory_dir() {
  local project_dir="$1"
  local claude_projects_dir="${HOME}/.claude/projects"

  if [[ ! -d "$claude_projects_dir" ]]; then
    echo ""
    return 1
  fi

  # Strategy 1: Look for directory containing the project path components
  local project_basename
  project_basename="$(basename "$project_dir")"

  local match
  match="$(find "$claude_projects_dir" -maxdepth 1 -type d -name "*${project_basename}*" 2>/dev/null | head -1)"

  if [[ -n "$match" ]]; then
    echo "${match}/memory"
    return 0
  fi

  # Strategy 2: Try common encoding patterns
  # Pattern: replace / with - and strip leading -
  local encoded="${project_dir//\//-}"
  encoded="${encoded#-}"
  if [[ -d "${claude_projects_dir}/${encoded}" ]]; then
    echo "${claude_projects_dir}/${encoded}/memory"
    return 0
  fi

  # Pattern: replace / and . with -
  encoded="${project_dir//[\/.]/-}"
  encoded="${encoded#-}"
  if [[ -d "${claude_projects_dir}/${encoded}" ]]; then
    echo "${claude_projects_dir}/${encoded}/memory"
    return 0
  fi

  # Fallback: not found
  _handover_log "WARNING: could not find Claude projects directory for ${project_dir}"
  echo ""
  return 1
}

# ---------------------------------------------------------------------------
# Initialization helper
# ---------------------------------------------------------------------------

# Create a minimal empty project-state.json
# Usage: init_project_state <output_file> <session_id>
init_project_state() {
  local output_file="$1"
  local session_id="${2:-unknown}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat > "$output_file" << JSONEOF
{
  "version": 2,
  "generated_at": "${now}",
  "session_id": "${session_id}",
  "status": "READY",
  "active_tasks": [],
  "recent_decisions": [],
  "architecture_changes": [],
  "known_issues": [],
  "session_hash": ""
}
JSONEOF
}
