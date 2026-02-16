#!/bin/bash
# claude-handover-lib.sh — shared utility functions for handover
# Source this file from claude-handover and claude-post-commit

readonly MAX_ARCHITECTURE_CHANGES=10

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
  if [[ "$version" != "2" && "$version" != "3" ]]; then
    _handover_log "ERROR: unsupported version: ${version} (expected 2 or 3)"
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

# Create a minimal empty project-state.json (v3)
# Usage: init_project_state <output_file> <session_id> [workspace_root] [workspace_branch] [is_worktree]
init_project_state() {
  local output_file="$1"
  local session_id="${2:-unknown}"
  local workspace_root="${3:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
  local workspace_branch="${4:-$(get_current_branch 2>/dev/null || echo "unknown")}"
  local is_worktree="${5:-false}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat > "$output_file" << JSONEOF
{
  "version": 3,
  "generated_at": "${now}",
  "session_id": "${session_id}",
  "status": "READY",
  "workspace": {
    "root": "${workspace_root}",
    "branch": "${workspace_branch}",
    "is_worktree": ${is_worktree}
  },
  "active_tasks": [],
  "recent_decisions": [],
  "architecture_changes": [],
  "known_issues": [],
  "session_hash": ""
}
JSONEOF
}

# ---------------------------------------------------------------------------
# Worktree-aware root resolution
# ---------------------------------------------------------------------------

# Get the current branch name, handling detached HEAD
# Outputs branch name or "detached-{sha7}"
# Returns 1 if not in a git repository
get_current_branch() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [[ -z "$branch" ]]; then
    _handover_log "ERROR: unable to determine branch (not in a git repository?)"
    return 1
  fi

  if [[ "$branch" == "HEAD" ]]; then
    local sha
    sha="$(git rev-parse --short=7 HEAD 2>/dev/null)"
    if [[ -z "$sha" ]]; then
      _handover_log "ERROR: unable to determine commit hash"
      return 1
    fi
    echo "detached-${sha}"
  else
    echo "$branch"
  fi
}

# Resolve the repository root (worktree-aware)
# git rev-parse --show-toplevel automatically returns:
# - worktree path if called from within a worktree
# - git toplevel path if called from main repo
# Usage: resolve_root
resolve_root() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"

  if [[ -z "$toplevel" ]]; then
    _handover_log "ERROR: not in a git repository"
    return 1
  fi

  echo "$toplevel"
}

# ---------------------------------------------------------------------------
# Handover directory resolution (branch + session fingerprint)
# ---------------------------------------------------------------------------

# Find an active (READY) session directory under the handover path.
# Search only — does NOT create directories.
# Returns 0 and outputs the directory path if found, 1 if not found.
# Usage: find_active_session_dir [project_root]
find_active_session_dir() {
  local root
  if [[ -n "${1:-}" ]]; then
    root="$1"
  else
    root="$(resolve_root)" || return 1
  fi

  local branch
  branch="$(get_current_branch)" || return 1

  local branch_dir="${root}/.claude/handover/${branch}"

  if [[ ! -d "$branch_dir" ]]; then
    return 1
  fi

  local session_dir
  for session_dir in "${branch_dir}"/*/; do
    [[ -d "$session_dir" ]] || continue

    local state_file="${session_dir}project-state.json"
    if [[ -f "$state_file" ]]; then
      local status
      status="$(jq -r '.status // "UNKNOWN"' "$state_file" 2>/dev/null)"
      if [[ "$status" == "READY" ]]; then
        echo "${session_dir%/}"
        return 0
      fi
    fi
  done

  return 1
}

# Resolve the full handover directory path with branch namespace and session fingerprint.
# - Reuses an existing READY session if found under {root}/.claude/handover/{branch}/
# - Creates a new fingerprinted directory if no active session exists
# Usage: resolve_handover_dir
# Outputs: absolute path to the handover directory
resolve_handover_dir() {
  local root
  root="$(resolve_root)" || return 1

  # Try to find existing active session
  local existing
  if existing="$(find_active_session_dir "$root")"; then
    echo "$existing"
    return 0
  fi

  # No active session found — generate a new fingerprint
  local branch
  branch="$(get_current_branch)" || return 1
  local fingerprint
  fingerprint="$(date +%Y%m%d-%H%M%S)"
  local new_dir="${root}/.claude/handover/${branch}/${fingerprint}"
  mkdir -p "$new_dir"
  echo "$new_dir"
}

# ---------------------------------------------------------------------------
# Session scanning
# ---------------------------------------------------------------------------

# Scan handover base directory for active (non-ALL_COMPLETE) sessions.
# Returns a JSON array of session objects.
# Usage: scan_sessions <handover_base_dir>
scan_sessions() {
  local handover_base_dir="$1"

  if [[ ! -d "$handover_base_dir" ]]; then
    echo "[]"
    return 0
  fi

  local results="[]"

  local branch_dir
  for branch_dir in "${handover_base_dir}"/*/; do
    [[ -d "$branch_dir" ]] || continue

    local session_dir
    for session_dir in "${branch_dir}"/*/; do
      [[ -d "$session_dir" ]] || continue

      local state_file="${session_dir}project-state.json"
      [[ -f "$state_file" ]] || continue

      # Validate JSON syntax
      if ! jq empty "$state_file" 2>/dev/null; then
        _handover_log "WARNING: skipping invalid JSON: ${state_file}"
        continue
      fi

      local status
      status="$(jq -r '.status // "UNKNOWN"' "$state_file")"

      # Skip ALL_COMPLETE sessions
      if [[ "$status" == "ALL_COMPLETE" ]]; then
        continue
      fi

      # Extract branch and fingerprint from path
      local fingerprint branch
      fingerprint="$(basename "${session_dir%/}")"
      branch="$(basename "${branch_dir%/}")"

      # Build session object and append to results
      results="$(echo "$results" | jq \
        --arg branch "$branch" \
        --arg fingerprint "$fingerprint" \
        --arg dir "${session_dir%/}" \
        --arg status "$status" \
        --arg state_file "$state_file" \
        --slurpfile state "$state_file" \
        '
        . + [{
          branch: $branch,
          fingerprint: $fingerprint,
          dir: $dir,
          status: $status,
          generated_at: ($state[0].generated_at // ""),
          total_tasks: (($state[0].active_tasks // []) | length),
          done_tasks: ([($state[0].active_tasks // [])[] | select(.status == "done")] | length),
          next_action: (
            [($state[0].active_tasks // [])[] | select(.status != "done")] |
            if length > 0 then .[0].description // "" else "" end
          )
        }]
        '
      )"
    done
  done

  echo "$results"
}

# ---------------------------------------------------------------------------
# Session cleanup
# ---------------------------------------------------------------------------

# Remove ALL_COMPLETE sessions older than N days.
# Usage: cleanup_old_sessions <handover_base_dir> <max_age_days>
cleanup_old_sessions() {
  local handover_base_dir="$1"
  local max_age_days="${2:-7}"

  if [[ ! -d "$handover_base_dir" ]]; then
    return 0
  fi

  local now_epoch
  now_epoch="$(date +%s)"
  local max_age_seconds=$((max_age_days * 86400))

  local branch_dir
  for branch_dir in "${handover_base_dir}"/*/; do
    [[ -d "$branch_dir" ]] || continue

    local session_dir
    for session_dir in "${branch_dir}"/*/; do
      [[ -d "$session_dir" ]] || continue

      local state_file="${session_dir}project-state.json"
      [[ -f "$state_file" ]] || continue

      # Validate JSON syntax
      if ! jq empty "$state_file" 2>/dev/null; then
        continue
      fi

      local status
      status="$(jq -r '.status // "UNKNOWN"' "$state_file")"

      # Only clean up ALL_COMPLETE sessions
      if [[ "$status" != "ALL_COMPLETE" ]]; then
        continue
      fi

      local generated_at
      generated_at="$(jq -r '.generated_at // ""' "$state_file")"

      if [[ -z "$generated_at" ]]; then
        continue
      fi

      # Parse timestamp to epoch — macOS first, Linux fallback
      local session_epoch
      session_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$generated_at" "+%s" 2>/dev/null)" \
        || session_epoch="$(date -d "$generated_at" "+%s" 2>/dev/null)" \
        || continue

      local age_seconds=$((now_epoch - session_epoch))

      if [[ $age_seconds -gt $max_age_seconds ]]; then
        _handover_log "Removing old completed session: ${session_dir%/}"
        rm -rf "${session_dir%/}"
      fi
    done

    # Remove empty branch directories after cleanup
    if [[ -d "$branch_dir" ]] && [[ -z "$(ls -A "${branch_dir%/}" 2>/dev/null)" ]]; then
      _handover_log "Removing empty branch directory: ${branch_dir%/}"
      rmdir "${branch_dir%/}" 2>/dev/null || true
    fi
  done
}
