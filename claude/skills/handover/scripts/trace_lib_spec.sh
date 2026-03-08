#!/bin/bash
# trace_lib_spec.sh — unit tests for trace-lib.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/trace-lib.sh" 2>/dev/null

PASS=0
FAIL=0
TOTAL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${label}"
    echo "  expected: ${expected}"
    echo "  actual:   ${actual}"
  fi
}

assert_file_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${label}"
    echo "  pattern not found: ${pattern}"
    echo "  file contents: $(cat "$file" 2>/dev/null || echo '(empty or missing)')"
  fi
}

assert_file_line_count() {
  local label="$1" file="$2" expected="$3"
  local actual
  actual=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
  assert_eq "$label" "$expected" "$actual"
}

assert_json_field() {
  local label="$1" file="$2" line_num="$3" field="$4" expected="$5"
  local actual
  actual=$(sed -n "${line_num}p" "$file" | jq -r "$field" 2>/dev/null)
  assert_eq "$label" "$expected" "$actual"
}

# ---- Setup ----
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---- Tests ----

echo "=== trace-lib.sh tests ==="

# Test 1: _trace_resolve_path
test_trace_resolve_path() {
  local result
  result=$(_trace_resolve_path "/tmp/handover/main/20260308")
  assert_eq "_trace_resolve_path returns correct path" \
    "/tmp/handover/main/20260308/trace.jsonl" "$result"
}

# Test 2: trace_phase_start writes valid JSONL
test_trace_phase_start() {
  local trace_file="${TMPDIR_TEST}/test_phase_start.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_phase_start "$trace_file" "feature-dev" 3 "Plan"

  assert_file_line_count "phase_start creates 1 line" "$trace_file" "1"
  assert_json_field "phase_start event type" "$trace_file" 1 ".event" "phase_start"
  assert_json_field "phase_start session_id" "$trace_file" 1 ".session_id" "test-session-1"
  assert_json_field "phase_start pipeline" "$trace_file" 1 ".data.pipeline" "feature-dev"
  assert_json_field "phase_start phase" "$trace_file" 1 ".data.phase" "3"
  assert_json_field "phase_start phase_name" "$trace_file" 1 ".data.phase_name" "Plan"
}

# Test 3: trace_phase_end writes valid JSONL
test_trace_phase_end() {
  local trace_file="${TMPDIR_TEST}/test_phase_end.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_phase_end "$trace_file" "feature-dev" 3 "Plan" 300000

  assert_json_field "phase_end event type" "$trace_file" 1 ".event" "phase_end"
  assert_json_field "phase_end duration_ms" "$trace_file" 1 ".data.duration_ms" "300000"
}

# Test 4: trace_agent_start and trace_agent_end
test_trace_agent_lifecycle() {
  local trace_file="${TMPDIR_TEST}/test_agent.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_agent_start "$trace_file" "code-review" "code-review-security" 2
  trace_agent_end "$trace_file" "code-review" "code-review-security" 2 90000 4 "json_direct"

  assert_file_line_count "agent lifecycle creates 2 lines" "$trace_file" "2"
  assert_json_field "agent_start event" "$trace_file" 1 ".event" "agent_start"
  assert_json_field "agent_end event" "$trace_file" 2 ".event" "agent_end"
  assert_json_field "agent_end findings_count" "$trace_file" 2 ".data.findings_count" "4"
  assert_json_field "agent_end parse_method" "$trace_file" 2 ".data.parse_method" "json_direct"
}

# Test 5: trace_user_decision with snapshot
test_trace_user_decision() {
  local trace_file="${TMPDIR_TEST}/test_decision.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_user_decision "$trace_file" "code-review" 3 '[1,3]' '[2]' \
    '[{"index":1,"severity":"high","category":"security","description":"SQL injection","selected":true},{"index":2,"severity":"medium","category":"quality","description":"Unused import","selected":false},{"index":3,"severity":"low","category":"performance","description":"N+1 query","selected":true}]'

  assert_json_field "user_decision event" "$trace_file" 1 ".event" "user_decision"
  assert_json_field "user_decision total" "$trace_file" 1 ".data.total_findings" "3"
  assert_json_field "user_decision selected count" "$trace_file" 1 '.data.selected | length | tostring' "2"
  assert_json_field "user_decision rejected count" "$trace_file" 1 '.data.rejected | length | tostring' "1"
  assert_json_field "user_decision snapshot count" "$trace_file" 1 '.data.findings_snapshot | length | tostring' "3"
}

# Test 6: trace_retry
test_trace_retry() {
  local trace_file="${TMPDIR_TEST}/test_retry.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_retry "$trace_file" "code-review" 5 2 "lint_failure"

  assert_json_field "retry event" "$trace_file" 1 ".event" "retry"
  assert_json_field "retry attempt" "$trace_file" 1 ".data.attempt" "2"
  assert_json_field "retry reason" "$trace_file" 1 ".data.reason" "lint_failure"
}

# Test 7: trace_error with message escaping
test_trace_error() {
  local trace_file="${TMPDIR_TEST}/test_error.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_error "$trace_file" "code-review" "code-review-quality" "parse_failure" 'JSON parse failed: unexpected "token" at position 42'

  assert_json_field "error event" "$trace_file" 1 ".event" "error"
  assert_json_field "error agent" "$trace_file" 1 ".data.agent" "code-review-quality"
  # Verify the line is valid JSON (jq can parse it)
  local valid
  valid=$(sed -n '1p' "$trace_file" | jq -r '.event' 2>/dev/null)
  assert_eq "error line is valid JSON" "error" "$valid"
}

# Test 8: trace_handover
test_trace_handover() {
  local trace_file="${TMPDIR_TEST}/test_handover.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_handover "$trace_file" "feature-dev" 4 "context_pressure"

  assert_json_field "handover event" "$trace_file" 1 ".event" "handover"
  assert_json_field "handover reason" "$trace_file" 1 ".data.reason" "context_pressure"
}

# Test 9: multiple events append correctly
test_append_multiple() {
  local trace_file="${TMPDIR_TEST}/test_append.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_phase_start "$trace_file" "feature-dev" 1 "Design"
  trace_phase_end "$trace_file" "feature-dev" 1 "Design" 60000
  trace_phase_start "$trace_file" "feature-dev" 2 "Spec Review"

  assert_file_line_count "append creates 3 lines" "$trace_file" "3"
  assert_json_field "line 1 is phase_start" "$trace_file" 1 ".event" "phase_start"
  assert_json_field "line 2 is phase_end" "$trace_file" 2 ".event" "phase_end"
  assert_json_field "line 3 is phase_start" "$trace_file" 3 ".event" "phase_start"
}

# Test 10: default session_id fallback
test_default_session_id() {
  local trace_file="${TMPDIR_TEST}/test_default_sid.jsonl"
  unset TRACE_SESSION_ID
  trace_phase_start "$trace_file" "test" 1 "Test"

  assert_json_field "default session_id is unknown" "$trace_file" 1 ".session_id" "unknown"
}

# Test 11: missing directory — graceful no-op
test_missing_directory() {
  local trace_file="/nonexistent/dir/trace.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_phase_start "$trace_file" "test" 1 "Test" 2>/dev/null
  local exit_code=$?

  assert_eq "missing dir returns 0 (no-op)" "0" "$exit_code"
}

# Test 12: ts field is ISO8601 format
test_timestamp_format() {
  local trace_file="${TMPDIR_TEST}/test_ts.jsonl"
  TRACE_SESSION_ID="test-session-1"
  trace_phase_start "$trace_file" "test" 1 "Test"

  local ts
  ts=$(sed -n '1p' "$trace_file" | jq -r '.ts')
  local match
  match=$(echo "$ts" | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$')
  assert_eq "ts is ISO8601 UTC format" "1" "$match"
}

# ---- Run all tests ----
test_trace_resolve_path
test_trace_phase_start
test_trace_phase_end
test_trace_agent_lifecycle
test_trace_user_decision
test_trace_retry
test_trace_error
test_trace_handover
test_append_multiple
test_default_session_id
test_missing_directory
test_timestamp_format

# ---- Summary ----
echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
