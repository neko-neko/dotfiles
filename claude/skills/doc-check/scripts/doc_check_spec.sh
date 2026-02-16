Describe "doc-check.sh"
  readonly FIXTURES_DIR="${SHELLSPEC_PROJECT_ROOT}/claude/skills/doc-check/scripts/fixtures"
  readonly DOC_CHECK_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/claude/skills/doc-check/scripts/doc-check.sh"

  Include "$DOC_CHECK_SCRIPT" --source-only

  Describe "parse_depends_on()"
    It "extracts depends-on entries from api.md"
      When call parse_depends_on "$FIXTURES_DIR/docs/api.md"
      The output should include "src/api/handler.ts"
      The output should include "src/api/routes/**/*.ts"
    End

    It "extracts depends-on from setup.md"
      When call parse_depends_on "$FIXTURES_DIR/docs/setup.md"
      The output should include "config/settings.yml"
    End

    It "returns empty for no-frontmatter.md"
      When call parse_depends_on "$FIXTURES_DIR/docs/no-frontmatter.md"
      The output should eq ""
    End

    It "returns empty for overview.md (no depends-on)"
      When call parse_depends_on "$FIXTURES_DIR/docs/overview.md"
      The output should eq ""
    End
  End

  Describe "match_glob()"
    It "matches exact path"
      When call match_glob "src/api/handler.ts" "src/api/handler.ts"
      The status should be success
    End

    It "matches ** recursive glob"
      When call match_glob "src/api/routes/**/*.ts" "src/api/routes/user.ts"
      The status should be success
    End

    It "rejects non-matching path"
      When call match_glob "src/api/handler.ts" "src/other/file.ts"
      The status should be failure
    End

    It "matches * single-level glob"
      When call match_glob "config/*.yml" "config/settings.yml"
      The status should be success
    End

    It "matches ** deep nested path"
      When call match_glob "src/**/*.ts" "src/api/routes/user.ts"
      The status should be success
    End

    It "matches ? single character"
      When call match_glob "src/?.ts" "src/a.ts"
      The status should be success
    End
  End

  Describe "extract_md_links()"
    It "extracts local md links from overview.md"
      When call extract_md_links "$FIXTURES_DIR/docs/overview.md" "$FIXTURES_DIR"
      The output should include "docs/api.md"
      The output should include "docs/setup.md"
    End

    It "excludes external URLs"
      When call extract_md_links "$FIXTURES_DIR/docs/overview.md" "$FIXTURES_DIR"
      The output should not include "https://example.com"
    End

    It "extracts links from setup.md"
      When call extract_md_links "$FIXTURES_DIR/docs/setup.md" "$FIXTURES_DIR"
      The output should include "docs/api.md"
    End

    It "returns empty for no-frontmatter.md (no links)"
      When call extract_md_links "$FIXTURES_DIR/docs/no-frontmatter.md" "$FIXTURES_DIR"
      The output should eq ""
    End
  End

  Describe "integration: --files mode"
    setup_git_repo() {
      cd "$FIXTURES_DIR"
      git init --quiet
      git add -A && git commit -m "init" --quiet
    }

    cleanup_git_repo() {
      rm -rf "$FIXTURES_DIR/.git"
      cd "$SHELLSPEC_PROJECT_ROOT"
    }

    run_doc_check() {
      cd "$FIXTURES_DIR"
      "$DOC_CHECK_SCRIPT" "$@"
    }

    BeforeAll 'setup_git_repo'
    AfterAll 'cleanup_git_repo'

    It "detects api.md for handler.ts change"
      When run run_doc_check --files src/api/routes/user.ts
      The output should include "docs/api.md"
      The output should include "src/api/routes/user.ts"
      The status should be failure  # exit 1 = impacts found
    End

    It "detects setup.md for settings.yml change"
      When run run_doc_check --files config/settings.yml
      The output should include "docs/setup.md"
      The status should be failure
    End

    It "detects chain impact: settings.yml -> setup.md -> overview.md"
      When run run_doc_check --files config/settings.yml
      The output should include "overview.md"
      The status should be failure  # exit 1 = impacts found
    End

    It "reports 0 impacts for unrelated file"
      When run run_doc_check --files README.md
      The output should include "0件"
      The status should be success
    End
  End
End
