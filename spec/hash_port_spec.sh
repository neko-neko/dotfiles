Describe "hash_port"
  HASH_PORT="$SHELLSPEC_PROJECT_ROOT/bin/hash_port"

  setup_git_repo() {
    TEST_REPO=$(mktemp -d)
    cd "$TEST_REPO"
    git init -q
    git -c user.name="test" -c user.email="test@test.com" \
      commit --allow-empty -q -m "init"
    git checkout -q -b "test/feature-branch"
  }

  cleanup_git_repo() {
    cd "$SHELLSPEC_PROJECT_ROOT"
    rm -rf "$TEST_REPO"
  }

  Before "setup_git_repo"
  After "cleanup_git_repo"

  Describe "ポート番号の生成"
    run_hash_port() { "$HASH_PORT"; }

    It "10000-19999 の範囲のポート番号を出力する"
      When run run_hash_port
      The output should match pattern "1[0-9][0-9][0-9][0-9]"
      The status should be success
    End

    It "同一ブランチで同じポート番号を返す（決定論性）"
      first_port() { "$HASH_PORT"; }
      second_port() { "$HASH_PORT"; }
      When call first_port
      The output should equal "$(second_port)"
    End
  End

  Describe "suffix による複数ポート生成"
    It "suffix なしと suffix ありで異なるポートを返す"
      no_suffix() { "$HASH_PORT"; }
      with_suffix() { "$HASH_PORT" db; }
      When call no_suffix
      The output should not equal "$(with_suffix)"
    End

    It "異なる suffix で異なるポートを返す"
      suffix_db() { "$HASH_PORT" db; }
      suffix_redis() { "$HASH_PORT" redis; }
      When call suffix_db
      The output should not equal "$(suffix_redis)"
    End

    run_hash_port_db() { "$HASH_PORT" db; }

    It "suffix 付きでも 10000-19999 の範囲内"
      When run run_hash_port_db
      The output should match pattern "1[0-9][0-9][0-9][0-9]"
      The status should be success
    End
  End

  Describe "エラーハンドリング"
    setup_non_git() {
      NON_GIT_DIR=$(mktemp -d)
      cd "$NON_GIT_DIR"
    }

    cleanup_non_git() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$NON_GIT_DIR"
    }

    Before "setup_non_git"
    After "cleanup_non_git"

    run_hash_port_non_git() { "$HASH_PORT"; }

    It "git リポジトリ外で exit 1 を返す"
      When run run_hash_port_non_git
      The status should be failure
      The stderr should include "hash_port"
    End
  End

  Describe "detached HEAD フォールバック"
    setup_detached_repo() {
      DETACHED_REPO=$(mktemp -d)
      cd "$DETACHED_REPO"
      git init -q
      git -c user.name="test" -c user.email="test@test.com" \
        commit --allow-empty -q -m "init"
      git checkout --detach -q
    }

    cleanup_detached_repo() {
      cd "$SHELLSPEC_PROJECT_ROOT"
      rm -rf "$DETACHED_REPO"
    }

    Before "setup_detached_repo"
    After "cleanup_detached_repo"

    run_hash_port_detached() { "$HASH_PORT"; }

    It "detached HEAD でも正常にポート番号を返す"
      When run run_hash_port_detached
      The status should be success
      The output should match pattern "1[0-9][0-9][0-9][0-9]"
    End
  End
End
