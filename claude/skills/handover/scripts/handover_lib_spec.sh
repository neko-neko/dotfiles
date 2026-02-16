Describe "handover-lib.sh"
  readonly FIXTURES_DIR="${SHELLSPEC_PROJECT_ROOT}/claude/skills/handover/scripts/fixtures"
  readonly SCRIPTS_DIR="${SHELLSPEC_PROJECT_ROOT}/claude/skills/handover/scripts"

  Include "$SCRIPTS_DIR/handover-lib.sh"

  # =========================================================================
  # Section 1: validate_project_state()
  # =========================================================================
  Describe "validate_project_state()"
    It "succeeds for valid v3 JSON"
      When call validate_project_state "$FIXTURES_DIR/valid-v3.json"
      The status should be success
    End

    It "fails for non-existent file"
      When call validate_project_state "/tmp/no-such-file-ever.json"
      The status should be failure
      The stderr should include "file not found"
    End

    It "fails for invalid JSON syntax"
      When call validate_project_state "$FIXTURES_DIR/invalid-syntax.json"
      The status should be failure
      The stderr should include "invalid JSON syntax"
    End

    It "fails for missing required fields"
      When call validate_project_state "$FIXTURES_DIR/invalid-missing-fields.json"
      The status should be failure
      The stderr should include "missing required fields"
    End

    It "fails for unsupported version"
      unsupported_version_json="$(mktemp)"
      jq '.version = 1' "$FIXTURES_DIR/valid-v3.json" > "$unsupported_version_json"
      When call validate_project_state "$unsupported_version_json"
      The status should be failure
      The stderr should include "unsupported version"
      rm -f "$unsupported_version_json"
    End

    It "fails for invalid status enum"
      invalid_status_json="$(mktemp)"
      jq '.status = "INVALID"' "$FIXTURES_DIR/valid-v3.json" > "$invalid_status_json"
      When call validate_project_state "$invalid_status_json"
      The status should be failure
      The stderr should include "invalid status"
      rm -f "$invalid_status_json"
    End
  End

  # =========================================================================
  # Section 2: compute_status()
  # =========================================================================
  Describe "compute_status()"
    It "returns ALL_COMPLETE when all tasks done"
      Data
        #|{"active_tasks":[{"status":"done"},{"status":"done"}]}
      End
      When call compute_status
      The output should eq "ALL_COMPLETE"
    End

    It "returns ALL_COMPLETE when no tasks"
      Data
        #|{"active_tasks":[]}
      End
      When call compute_status
      The output should eq "ALL_COMPLETE"
    End

    It "returns READY when some tasks not done"
      Data
        #|{"active_tasks":[{"status":"done"},{"status":"in_progress"}]}
      End
      When call compute_status
      The output should eq "READY"
    End

    It "returns READY when a task is blocked"
      Data
        #|{"active_tasks":[{"status":"done"},{"status":"blocked"}]}
      End
      When call compute_status
      The output should eq "READY"
    End
  End

  # =========================================================================
  # Section 3: add_architecture_change()
  # =========================================================================
  Describe "add_architecture_change()"
    setup_arch() { work_json="$(mktemp)"; cp "$FIXTURES_DIR/mixed-tasks.json" "$work_json"; }
    cleanup_arch() { rm -f "$work_json"; }
    BeforeEach 'setup_arch'
    AfterEach 'cleanup_arch'

    It "appends entry with sha and summary"
      When call add_architecture_change "$work_json" "deadbeef" "Added new module" '["src/new.sh"]' "2026-02-17T00:00:00Z"
      The status should be success
      The contents of file "$work_json" should include "deadbeef"
      The contents of file "$work_json" should include "Added new module"
    End

    It "trims to MAX_ARCHITECTURE_CHANGES"
      add_many_entries() {
        local i
        for i in $(seq 1 11); do
          add_architecture_change "$work_json" "sha${i}" "Change ${i}" '["f.sh"]' "2026-02-17T00:00:00Z"
        done
      }
      When call add_many_entries
      The status should be success
      The contents of file "$work_json" should not include '"sha1"'
      The contents of file "$work_json" should include '"sha11"'
    End
  End

  # =========================================================================
  # Section 4: touch_related_tasks()
  # =========================================================================
  Describe "touch_related_tasks()"
    setup_touch() { work_json="$(mktemp)"; cp "$FIXTURES_DIR/mixed-tasks.json" "$work_json"; }
    cleanup_touch() { rm -f "$work_json"; }
    BeforeEach 'setup_touch'
    AfterEach 'cleanup_touch'

    It "updates last_touched for matching file_paths"
      When call touch_related_tasks "$work_json" '["src/b.sh"]' "2026-02-17T12:00:00Z"
      The status should be success
      The contents of file "$work_json" should include "2026-02-17T12:00:00Z"
    End

    It "does not touch unrelated tasks"
      When call touch_related_tasks "$work_json" '["src/unrelated.sh"]' "2099-01-01T00:00:00Z"
      The status should be success
      The contents of file "$work_json" should not include "2099-01-01T00:00:00Z"
    End
  End

  # =========================================================================
  # Section 5: update_status_field()
  # =========================================================================
  Describe "update_status_field()"
    It "sets ALL_COMPLETE when all done"
      work_json="$(mktemp)"
      cp "$FIXTURES_DIR/all-complete.json" "$work_json"
      # Force status to READY so update_status_field must auto-correct
      tmp_fix="$(mktemp)"
      jq '.status = "READY"' "$work_json" > "$tmp_fix" && mv "$tmp_fix" "$work_json"
      When call update_status_field "$work_json"
      The status should be success
      The contents of file "$work_json" should include '"status": "ALL_COMPLETE"'
      rm -f "$work_json"
    End

    It "sets READY when tasks pending"
      work_json="$(mktemp)"
      cp "$FIXTURES_DIR/mixed-tasks.json" "$work_json"
      When call update_status_field "$work_json"
      The status should be success
      The contents of file "$work_json" should include '"status": "READY"'
      rm -f "$work_json"
    End
  End

  # =========================================================================
  # Section 6: generate_handover_md()
  # =========================================================================
  Describe "generate_handover_md()"
    setup_md() { md_output="$(mktemp)"; }
    cleanup_md() { rm -f "$md_output"; }
    BeforeEach 'setup_md'
    AfterEach 'cleanup_md'

    It "includes correct header sections"
      When call generate_handover_md "$FIXTURES_DIR/mixed-tasks.json" "$md_output"
      The status should be success
      The contents of file "$md_output" should include "Session Handover"
      The contents of file "$md_output" should include "Completed"
      The contents of file "$md_output" should include "[T1]"
      The contents of file "$md_output" should include "abc1234"
    End

    It "includes remaining tasks (in_progress, blocked)"
      When call generate_handover_md "$FIXTURES_DIR/mixed-tasks.json" "$md_output"
      The status should be success
      The contents of file "$md_output" should include "in_progress"
      The contents of file "$md_output" should include "blocked"
    End

    It "includes blockers section"
      When call generate_handover_md "$FIXTURES_DIR/mixed-tasks.json" "$md_output"
      The status should be success
      The contents of file "$md_output" should include "PR #42 pending"
    End

    It "includes known issues"
      When call generate_handover_md "$FIXTURES_DIR/mixed-tasks.json" "$md_output"
      The status should be success
      The contents of file "$md_output" should include "[high]"
      The contents of file "$md_output" should include "Memory leak in Y"
    End

    It "fails for invalid JSON input"
      When call generate_handover_md "$FIXTURES_DIR/invalid-syntax.json" "$md_output"
      The status should be failure
      The stderr should include "invalid JSON syntax"
    End
  End

  # =========================================================================
  # Section 7: compute_session_hash()
  # =========================================================================
  Describe "compute_session_hash()"
    It "produces consistent hash for same content"
      hash1="$(compute_session_hash "$FIXTURES_DIR/valid-v3.json")"
      When call compute_session_hash "$FIXTURES_DIR/valid-v3.json"
      The output should eq "$hash1"
    End

    It "produces 64-char hex string"
      When call compute_session_hash "$FIXTURES_DIR/valid-v3.json"
      The output should match pattern "????????????????????????????????????????????????????????????????"
      The length of output should eq 64
    End
  End

  # =========================================================================
  # Section 8: store_session_hash()
  # =========================================================================
  Describe "store_session_hash()"
    It "stores non-empty hash in JSON"
      work_json="$(mktemp)"
      cp "$FIXTURES_DIR/valid-v3.json" "$work_json"
      When call store_session_hash "$work_json"
      The status should be success
      The contents of file "$work_json" should not include '"session_hash": ""'
      rm -f "$work_json"
    End
  End

  # =========================================================================
  # Section 9: has_state_changed()
  # =========================================================================
  Describe "has_state_changed()"
    It "returns 0 (changed) for non-existent file"
      When call has_state_changed "/tmp/no-such-state-file-ever.json"
      The status should be success
    End

    It "returns 0 (changed) when hash is empty"
      When call has_state_changed "$FIXTURES_DIR/valid-v3.json"
      The status should be success
    End

    It "returns 1 (unchanged) after store_session_hash"
      work_json="$(mktemp)"
      cp "$FIXTURES_DIR/valid-v3.json" "$work_json"
      store_session_hash "$work_json"
      When call has_state_changed "$work_json"
      The status should be failure
      rm -f "$work_json"
    End
  End

  # =========================================================================
  # Section 10: get_current_branch()
  # =========================================================================
  Describe "get_current_branch()"
    It "returns branch name"
      git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--abbrev-ref" ]; then
          echo "feature/test-branch"
          return 0
        fi
      }
      When call get_current_branch
      The output should eq "feature/test-branch"
    End

    It "returns detached-SHA for detached HEAD"
      git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--abbrev-ref" ]; then
          echo "HEAD"
          return 0
        fi
        if [ "$1" = "rev-parse" ] && [ "$2" = "--short=7" ]; then
          echo "abc1234"
          return 0
        fi
      }
      When call get_current_branch
      The output should eq "detached-abc1234"
    End

    It "returns failure when not in git repo"
      git() {
        echo ""
        return 1
      }
      When call get_current_branch
      The status should be failure
      The stderr should include "unable to determine branch"
    End
  End

  # =========================================================================
  # Section 11: resolve_root()
  # =========================================================================
  Describe "resolve_root()"
    It "returns git toplevel path"
      git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--show-toplevel" ]; then
          echo "/home/user/project"
          return 0
        fi
      }
      When call resolve_root
      The output should eq "/home/user/project"
    End

    It "returns failure when not in git repo"
      git() {
        echo ""
        return 1
      }
      When call resolve_root
      The status should be failure
      The stderr should include "not in a git repository"
    End
  End

  # =========================================================================
  # Section 12: find_active_session_dir()
  # =========================================================================
  Describe "find_active_session_dir()"
    setup_session_dir() {
      test_root="$(mktemp -d)"
      mkdir -p "$test_root/.claude/handover/main/session-001"
      cp "$FIXTURES_DIR/valid-v3.json" "$test_root/.claude/handover/main/session-001/project-state.json"
      mkdir -p "$test_root/.claude/handover/main/session-002"
      cp "$FIXTURES_DIR/all-complete.json" "$test_root/.claude/handover/main/session-002/project-state.json"
    }
    cleanup_session_dir() { rm -rf "$test_root"; }
    BeforeEach 'setup_session_dir'
    AfterEach 'cleanup_session_dir'

    It "finds READY session directory"
      git() {
        case "$2" in
          --abbrev-ref) echo "main"; return 0 ;;
          --show-toplevel) echo "$test_root"; return 0 ;;
        esac
      }
      When call find_active_session_dir "$test_root"
      The status should be success
      The output should include "session-001"
    End

    It "returns failure when no sessions exist (different branch)"
      git() {
        case "$2" in
          --abbrev-ref) echo "other-branch"; return 0 ;;
          --show-toplevel) echo "$test_root"; return 0 ;;
        esac
      }
      When call find_active_session_dir "$test_root"
      The status should be failure
    End

    It "skips ALL_COMPLETE sessions"
      # Remove the READY session, leaving only ALL_COMPLETE
      rm -rf "$test_root/.claude/handover/main/session-001"
      git() {
        case "$2" in
          --abbrev-ref) echo "main"; return 0 ;;
          --show-toplevel) echo "$test_root"; return 0 ;;
        esac
      }
      When call find_active_session_dir "$test_root"
      The status should be failure
    End
  End

  # =========================================================================
  # Section 13: scan_sessions()
  # =========================================================================
  Describe "scan_sessions()"
    setup_scan() {
      test_root="$(mktemp -d)"
      mkdir -p "$test_root/main/session-001"
      cp "$FIXTURES_DIR/valid-v3.json" "$test_root/main/session-001/project-state.json"
      mkdir -p "$test_root/main/session-002"
      cp "$FIXTURES_DIR/all-complete.json" "$test_root/main/session-002/project-state.json"
    }
    cleanup_scan() { rm -rf "$test_root"; }
    BeforeEach 'setup_scan'
    AfterEach 'cleanup_scan'

    It "returns active sessions as JSON array (includes READY, excludes ALL_COMPLETE)"
      When call scan_sessions "$test_root"
      The output should include "session-001"
      The output should not include "session-002"
      The output should include "READY"
    End

    It "returns empty array for non-existent directory"
      When call scan_sessions "/tmp/no-such-handover-dir-ever"
      The output should eq "[]"
    End
  End

  # =========================================================================
  # Section 14: cleanup_old_sessions()
  # =========================================================================
  Describe "cleanup_old_sessions()"
    setup_cleanup() {
      test_root="$(mktemp -d)"
      # Old ALL_COMPLETE session (2025-12-01, ~78 days ago)
      mkdir -p "$test_root/main/old-session"
      old_json="$test_root/main/old-session/project-state.json"
      jq '.generated_at = "2025-12-01T00:00:00Z"' "$FIXTURES_DIR/all-complete.json" > "$old_json"
      # Recent ALL_COMPLETE session (2026-02-16, 1 day ago)
      mkdir -p "$test_root/main/recent-session"
      recent_json="$test_root/main/recent-session/project-state.json"
      jq '.generated_at = "2026-02-16T00:00:00Z"' "$FIXTURES_DIR/all-complete.json" > "$recent_json"
    }
    cleanup_cleanup() { rm -rf "$test_root"; }
    BeforeEach 'setup_cleanup'
    AfterEach 'cleanup_cleanup'

    It "removes sessions older than max_age_days"
      When call cleanup_old_sessions "$test_root" 7
      The status should be success
      The stderr should include "Removing old completed session"
      The path "$test_root/main/old-session" should not be exist
    End

    It "keeps recent sessions"
      When call cleanup_old_sessions "$test_root" 7
      The status should be success
      The stderr should include "Removing old completed session"
      The path "$test_root/main/recent-session" should be exist
    End
  End

  # =========================================================================
  # Section 15: find_memory_dir()
  # =========================================================================
  Describe "find_memory_dir()"
    It "returns failure when projects directory does not exist"
      saved_home="$HOME"
      HOME="$(mktemp -d)"
      When call find_memory_dir "/some/project"
      The status should be failure
      The output should eq ""
      HOME="$saved_home"
    End
  End

  # =========================================================================
  # Section 16: init_project_state()
  # =========================================================================
  Describe "init_project_state()"
    It "creates valid v3 project-state.json with correct fields"
      work_json="$(mktemp)"
      git() {
        case "$2" in
          --show-toplevel) echo "/tmp/test-repo"; return 0 ;;
          --abbrev-ref) echo "main"; return 0 ;;
        esac
      }
      When call init_project_state "$work_json" "test-session-id"
      The status should be success
      The contents of file "$work_json" should include '"version": 3'
      The contents of file "$work_json" should include '"session_id": "test-session-id"'
      The contents of file "$work_json" should include '"status": "READY"'
      The contents of file "$work_json" should include '"active_tasks": []'
      rm -f "$work_json"
    End
  End
End
