Describe "tmux-session-name"
  TMUX_SESSION_NAME="$SHELLSPEC_PROJECT_ROOT/bin/tmux-session-name"

  setup_git_repo() {
    TEST_ROOT=$(mktemp -d)
    mkdir "$TEST_ROOT/myproj"
    cd "$TEST_ROOT/myproj"
    git init -q -b main
    git -c user.name="test" -c user.email="test@test.com" \
      commit --allow-empty -q -m "init"
  }

  cleanup_git_repo() {
    cd "$SHELLSPEC_PROJECT_ROOT"
    rm -rf "$TEST_ROOT"
  }

  Describe "基本動作"
    Before "setup_git_repo"
    After  "cleanup_git_repo"

    run_name() { "$TMUX_SESSION_NAME"; }

    It "<repo>-<branch> 形式で名前を返す"
      When run run_name
      The output should equal "myproj-main"
      The status should be success
    End
  End
End
