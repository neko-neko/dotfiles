Describe "post-commit.sh"
  # post-commit.sh is a standalone script (not a library), so we test it
  # by running it as a subprocess with mocked environment. The script's
  # core logic (handover-lib functions) is already tested in handover_lib_spec.sh.
  #
  # Here we focus on integration-level smoke tests:
  #   1. Script exits gracefully when not in a git repo
  #   2. Script exits gracefully when no active handover session exists
  #   3. Script completes the full update flow with an active session

  readonly POST_COMMIT_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/claude/hooks/post-commit.sh"
  readonly FIXTURES_DIR="${SHELLSPEC_PROJECT_ROOT}/claude/skills/handover/scripts/fixtures"

  # =========================================================================
  # Helper: create a mock bin directory with stub commands
  # =========================================================================
  setup_mock_bin() {
    MOCK_BIN="$(mktemp -d)"

    # git stub — behaviour controlled by GIT_MOCK_MODE env var
    cat > "${MOCK_BIN}/git" << 'GITEOF'
#!/bin/bash
case "${GIT_MOCK_MODE:-}" in
  no-repo)
    # Output empty string and succeed — under set -euo pipefail,
    # a failing command substitution in ${VAR:-$(...)} kills the script.
    # Returning empty lets the script reach its own -z check.
    if [[ "${*}" == *"--show-toplevel"* ]]; then
      echo ""
      exit 0
    fi
    exit 0
    ;;
  has-repo)
    if [[ "${*}" == *"--show-toplevel"* ]]; then
      echo "${MOCK_PROJECT_DIR}"
      exit 0
    fi
    if [[ "${*}" == *"--abbrev-ref"* ]]; then
      echo "main"
      exit 0
    fi
    if [[ "${*}" == *"log -1 --format=%H"* ]]; then
      echo "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
      exit 0
    fi
    if [[ "${*}" == *"log -1 --format=%s"* ]]; then
      echo "test commit message"
      exit 0
    fi
    if [[ "${*}" == *"rev-parse HEAD~1"* ]]; then
      exit 1  # first commit, no parent
    fi
    if [[ "${*}" == *"diff --stat"* ]]; then
      echo " src/test.sh | 10 ++++"
      exit 0
    fi
    if [[ "${*}" == *"diff --name-only"* ]]; then
      echo "src/test.sh"
      exit 0
    fi
    exit 0
    ;;
esac
exit 1
GITEOF
    chmod +x "${MOCK_BIN}/git"

    # claude stub — returns summary
    cat > "${MOCK_BIN}/claude" << 'CLAUDEEOF'
#!/bin/bash
echo "テストコミットの要約"
CLAUDEEOF
    chmod +x "${MOCK_BIN}/claude"

    # jq — use real jq (required for JSON manipulation)
    local real_jq
    real_jq="$(command -v jq)"
    if [[ -n "$real_jq" ]]; then
      ln -sf "$real_jq" "${MOCK_BIN}/jq"
    fi

    # date — use real date
    local real_date
    real_date="$(command -v date)"
    if [[ -n "$real_date" ]]; then
      ln -sf "$real_date" "${MOCK_BIN}/date"
    fi

    # cut — use real cut
    local real_cut
    real_cut="$(command -v cut)"
    if [[ -n "$real_cut" ]]; then
      ln -sf "$real_cut" "${MOCK_BIN}/cut"
    fi

    # cat — use real cat
    local real_cat
    real_cat="$(command -v cat)"
    if [[ -n "$real_cat" ]]; then
      ln -sf "$real_cat" "${MOCK_BIN}/cat"
    fi

    # shasum — use real shasum
    local real_shasum
    real_shasum="$(command -v shasum)"
    if [[ -n "$real_shasum" ]]; then
      ln -sf "$real_shasum" "${MOCK_BIN}/shasum"
    fi

    # mktemp — use real mktemp
    local real_mktemp
    real_mktemp="$(command -v mktemp)"
    if [[ -n "$real_mktemp" ]]; then
      ln -sf "$real_mktemp" "${MOCK_BIN}/mktemp"
    fi

    # mv — use real mv
    local real_mv
    real_mv="$(command -v mv)"
    if [[ -n "$real_mv" ]]; then
      ln -sf "$real_mv" "${MOCK_BIN}/mv"
    fi

    # basename — use real basename
    local real_basename
    real_basename="$(command -v basename)"
    if [[ -n "$real_basename" ]]; then
      ln -sf "$real_basename" "${MOCK_BIN}/basename"
    fi

    # echo — use system echo (needed by git mock)
    local real_echo
    real_echo="$(command -v echo)"
    if [[ -n "$real_echo" && -f "$real_echo" ]]; then
      ln -sf "$real_echo" "${MOCK_BIN}/echo"
    fi

    # ls — use real ls
    local real_ls
    real_ls="$(command -v ls)"
    if [[ -n "$real_ls" ]]; then
      ln -sf "$real_ls" "${MOCK_BIN}/ls"
    fi

    # mkdir — use real mkdir
    local real_mkdir
    real_mkdir="$(command -v mkdir)"
    if [[ -n "$real_mkdir" ]]; then
      ln -sf "$real_mkdir" "${MOCK_BIN}/mkdir"
    fi

    # chmod — use real chmod
    local real_chmod
    real_chmod="$(command -v chmod)"
    if [[ -n "$real_chmod" ]]; then
      ln -sf "$real_chmod" "${MOCK_BIN}/chmod"
    fi

    # cd — built-in, no need to link

    # dirname — use real dirname
    local real_dirname
    real_dirname="$(command -v dirname)"
    if [[ -n "$real_dirname" ]]; then
      ln -sf "$real_dirname" "${MOCK_BIN}/dirname"
    fi

    # pwd — use real pwd
    local real_pwd
    real_pwd="$(command -v pwd)"
    if [[ -n "$real_pwd" && -f "$real_pwd" ]]; then
      ln -sf "$real_pwd" "${MOCK_BIN}/pwd"
    fi
  }

  cleanup_mock_bin() {
    rm -rf "$MOCK_BIN"
  }

  # =========================================================================
  # Helper: run post-commit.sh with controlled PATH
  # =========================================================================
  run_post_commit() {
    # Run the script with our mock bin first in PATH
    env \
      PATH="${MOCK_BIN}:/usr/bin:/bin" \
      GIT_MOCK_MODE="${GIT_MOCK_MODE}" \
      MOCK_PROJECT_DIR="${MOCK_PROJECT_DIR:-}" \
      CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}" \
      HOME="${HOME}" \
      bash "$POST_COMMIT_SCRIPT"
  }

  # =========================================================================
  # Test 1: no git repository -> exit 0
  # =========================================================================
  Describe "when not in a git repository"
    setup_no_repo() {
      setup_mock_bin
      GIT_MOCK_MODE="no-repo"
      CLAUDE_PROJECT_DIR=""
    }
    cleanup_no_repo() {
      cleanup_mock_bin
    }
    BeforeEach 'setup_no_repo'
    AfterEach 'cleanup_no_repo'

    It "exits 0 with 'not in a git repository' message"
      When run run_post_commit
      The status should be success
      The stderr should include "not in a git repository"
    End
  End

  # =========================================================================
  # Test 2: no active handover session -> exit 0
  # =========================================================================
  Describe "when no active handover session exists"
    setup_no_session() {
      setup_mock_bin
      GIT_MOCK_MODE="has-repo"
      MOCK_PROJECT_DIR="$(mktemp -d)"
      CLAUDE_PROJECT_DIR="${MOCK_PROJECT_DIR}"
      # Don't create any .claude/handover/ directory — no session
    }
    cleanup_no_session() {
      cleanup_mock_bin
      rm -rf "$MOCK_PROJECT_DIR"
    }
    BeforeEach 'setup_no_session'
    AfterEach 'cleanup_no_session'

    It "exits 0 with 'no active handover session' message"
      When run run_post_commit
      The status should be success
      The stderr should include "no active handover session"
    End
  End

  # =========================================================================
  # Test 3: active session exists -> full update flow
  # =========================================================================
  Describe "when an active handover session exists"
    setup_full_flow() {
      setup_mock_bin
      GIT_MOCK_MODE="has-repo"
      MOCK_PROJECT_DIR="$(mktemp -d)"
      CLAUDE_PROJECT_DIR="${MOCK_PROJECT_DIR}"

      # Create session directory with valid project-state.json
      local session_dir="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session"
      mkdir -p "$session_dir"
      cp "$FIXTURES_DIR/valid-v3.json" "${session_dir}/project-state.json"
    }
    cleanup_full_flow() {
      cleanup_mock_bin
      rm -rf "$MOCK_PROJECT_DIR"
    }
    BeforeEach 'setup_full_flow'
    AfterEach 'cleanup_full_flow'

    It "updates project-state.json and generates handover.md"
      When run run_post_commit
      The status should be success
      The stderr should include "updated project-state.json and handover.md"
    End

    It "adds architecture_changes entry with commit SHA"
      run_post_commit >/dev/null 2>&1
      local state_file="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session/project-state.json"
      When call jq -r '.architecture_changes[-1].commit_sha' "$state_file"
      The output should eq "deadbee"
    End

    It "generates handover.md file"
      run_post_commit >/dev/null 2>&1
      local handover_file="${MOCK_PROJECT_DIR}/.claude/handover/main/test-session/handover.md"
      When call cat "$handover_file"
      The output should include "Session Handover"
    End
  End
End
