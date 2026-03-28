Describe "doc-audit.sh"
  readonly AUDIT_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/claude/skills/doc-audit/scripts/doc-audit.sh"
  readonly AUDIT_FIXTURES_DIR="${SHELLSPEC_PROJECT_ROOT}/claude/skills/doc-check/scripts/fixtures"

  Include "$AUDIT_SCRIPT" --source-only

  Describe "check_broken_deps()"
    It "detects nonexistent-file.ts as broken dependency"
      When call check_broken_deps "$AUDIT_FIXTURES_DIR"
      The output should include "nonexistent-file.ts"
      The status should be success
    End

    It "does not flag handler.ts which exists"
      When call check_broken_deps "$AUDIT_FIXTURES_DIR"
      The output should not include '"missing":"src/api/handler.ts"'
      The status should be success
    End

    It "returns valid JSON array"
      When call check_broken_deps "$AUDIT_FIXTURES_DIR"
      The output should start with "["
      The output should end with "]"
    End
  End

  Describe "check_dead_links()"
    It "detects nonexistent.md as dead link"
      When call check_dead_links "$AUDIT_FIXTURES_DIR"
      The output should include "nonexistent.md"
      The status should be success
    End

    It "returns valid JSON array"
      When call check_dead_links "$AUDIT_FIXTURES_DIR"
      The output should start with "["
      The output should end with "]"
    End
  End

  Describe "check_undeclared_deps()"
    It "detects src/api/routes/user.ts as undeclared dependency"
      When call check_undeclared_deps "$AUDIT_FIXTURES_DIR"
      The output should include "src/api/routes/user.ts"
      The status should be success
    End

    It "does not flag src/api/handler.ts which is in depends-on"
      When call check_undeclared_deps "$AUDIT_FIXTURES_DIR"
      The output should not include '"mentioned":"src/api/handler.ts"'
      The status should be success
    End

    It "returns valid JSON array"
      When call check_undeclared_deps "$AUDIT_FIXTURES_DIR"
      The output should start with "["
      The output should end with "]"
    End
  End

  Describe "check_orphaned_docs()"
    It "detects orphaned.md as orphaned"
      When call check_orphaned_docs "$AUDIT_FIXTURES_DIR"
      The output should include "orphaned.md"
      The status should be success
    End

    It "does not flag api.md which is linked from overview.md"
      When call check_orphaned_docs "$AUDIT_FIXTURES_DIR"
      The output should not include '"docs/api.md"'
      The status should be success
    End

    It "returns valid JSON array"
      When call check_orphaned_docs "$AUDIT_FIXTURES_DIR"
      The output should start with "["
      The output should end with "]"
    End
  End

  Describe "check_stale_signals()"
    It "function exists and is callable"
      When call type check_stale_signals
      The output should include "function"
      The status should be success
    End
  End

  Describe "integration: --full --json --root"
    setup_audit_git_repo() {
      cd "$AUDIT_FIXTURES_DIR"
      if [[ ! -d ".git" ]]; then
        git init --quiet
        git add -A && git commit -m "init" --quiet
      fi
    }

    cleanup_audit_git_repo() {
      rm -rf "$AUDIT_FIXTURES_DIR/.git"
      cd "$SHELLSPEC_PROJECT_ROOT"
    }

    run_audit() {
      "$AUDIT_SCRIPT" "$@"
    }

    BeforeAll 'setup_audit_git_repo'
    AfterAll 'cleanup_audit_git_repo'

    It "outputs JSON with all required keys"
      When run run_audit --full --json --root "$AUDIT_FIXTURES_DIR"
      The output should include '"broken_deps"'
      The output should include '"undeclared_deps"'
      The output should include '"orphaned_docs"'
      The output should include '"dead_links"'
      The output should include '"stale_signals"'
      The output should include '"meta"'
      The status should be failure
    End

    It "includes meta with total_docs_scanned"
      When run run_audit --full --json --root "$AUDIT_FIXTURES_DIR"
      The output should include '"total_docs_scanned"'
      The output should include '"scope":"full"'
      The status should be failure
    End

    It "exits with 1 when issues found"
      When run run_audit --full --json --root "$AUDIT_FIXTURES_DIR"
      The output should include '"broken_deps"'
      The status should be failure
    End
  End
End
