Describe "drop-upload/lib/core.sh"
  Include "$SHELLSPEC_PROJECT_ROOT/config/herdr/plugins/drop-upload/lib/core.sh"

  Describe "parse_dropped_paths"
    It "素のパス1件をそのまま返す"
      When call parse_dropped_paths "/tmp/file.txt"
      The output should equal "/tmp/file.txt"
      The status should be success
    End

    It "スペース区切りの複数パスを1行1件に分割する"
      When call parse_dropped_paths "/tmp/a.txt /tmp/b.txt"
      The line 1 of output should equal "/tmp/a.txt"
      The line 2 of output should equal "/tmp/b.txt"
    End

    It "backslash エスケープされたスペースを復元する"
      When call parse_dropped_paths "/tmp/My\\ File.txt"
      The output should equal "/tmp/My File.txt"
    End

    It "ダブルクォート囲みを外す"
      When call parse_dropped_paths "\"/tmp/My File.txt\""
      The output should equal "/tmp/My File.txt"
    End

    It "シングルクォート囲みを外す"
      When call parse_dropped_paths "'/tmp/My File.txt'"
      The output should equal "/tmp/My File.txt"
    End

    It "file:// URL の %XX をデコードする（日本語含む）"
      When call parse_dropped_paths "file:///tmp/My%20%E3%83%86%E3%82%B9%E3%83%88.png"
      The output should equal "/tmp/My テスト.png"
    End

    It "不正クォート（アポストロフィ入りファイル名）は行全体を1パスとして扱う"
      When call parse_dropped_paths "/tmp/it's here.txt"
      The output should equal "/tmp/it's here.txt"
    End

    It "末尾の CR と前後の空白を除去する"
      When call parse_dropped_paths "  /tmp/file.txt $(printf '\r')"
      The output should equal "/tmp/file.txt"
    End

    It "空行は exit 1"
      When call parse_dropped_paths "   "
      The status should be failure
    End
  End

  Describe "extract_ssh_target"
    It "ssh dev から dest=dev を抽出する"
      When call extract_ssh_target ssh dev
      The output should equal "dest=dev"
      The status should be success
    End

    It "ssh user@host から dest=user@host を抽出する"
      When call extract_ssh_target ssh user@host
      The output should equal "dest=user@host"
    End

    It "-p 2222 を port として抽出する"
      When call extract_ssh_target ssh -p 2222 user@host
      The line 1 of output should equal "dest=user@host"
      The line 2 of output should equal "port=2222"
    End

    It "-p2222（結合形式）も port として抽出する"
      When call extract_ssh_target ssh -p2222 host
      The line 1 of output should equal "dest=host"
      The line 2 of output should equal "port=2222"
    End

    It "値付きオプションをスキップし -l をユーザーとして合成、リモートコマンドは無視する"
      When call extract_ssh_target ssh -l user -i /k -o StrictHostKeyChecking=no host tail -f /log
      The output should equal "dest=user@host"
    End

    It "ssh://user@host:2222 形式を分解する"
      When call extract_ssh_target ssh ssh://user@host:2222
      The line 1 of output should equal "dest=user@host"
      The line 2 of output should equal "port=2222"
    End

    It "ポート無し IPv6 URI (ssh://[::1]) を dest=[::1] として扱う"
      When call extract_ssh_target ssh "ssh://[::1]"
      The output should equal "dest=[::1]"
    End

    It "ポート付き IPv6 URI (ssh://user@[::1]:2222) を分解する"
      When call extract_ssh_target ssh "ssh://user@[::1]:2222"
      The line 1 of output should equal "dest=user@[::1]"
      The line 2 of output should equal "port=2222"
    End

    It "ssh 以外のコマンドは exit 1"
      When call extract_ssh_target -zsh
      The status should be failure
    End

    It "destination が無い場合は exit 1"
      When call extract_ssh_target ssh -v
      The status should be failure
    End
  End

  Describe "extract_ssh_argv_from_process_info"
    ssh_fixture() {
      cat <<'JSON'
{"id":"cli:pane:process_info","result":{"process_info":{"foreground_processes":[{"argv":["zsh","-l"],"argv0":"zsh","cmdline":"zsh -l","name":"zsh","pid":1},{"argv":["ssh","-p","2222","user@host"],"argv0":"ssh","cmdline":"ssh -p 2222 user@host","name":"ssh","pid":2}],"pane_id":"w1:p1","shell_pid":1}}}
JSON
    }

    no_ssh_fixture() {
      cat <<'JSON'
{"id":"cli:pane:process_info","result":{"process_info":{"foreground_processes":[{"argv":["vim","x.txt"],"argv0":"vim","cmdline":"vim x.txt","name":"vim","pid":3}],"pane_id":"w1:p1","shell_pid":1}}}
JSON
    }

    cmdline_only_fixture() {
      cat <<'JSON'
{"id":"cli:pane:process_info","result":{"process_info":{"foreground_processes":[{"argv0":"ssh","cmdline":"ssh user@host","name":"ssh","pid":4}],"pane_id":"w1:p1","shell_pid":1}}}
JSON
    }

    It "ssh プロセスの argv を1行1トークンで返す"
      extract_from_ssh() { extract_ssh_argv_from_process_info "$(ssh_fixture)"; }
      When call extract_from_ssh
      The line 1 of output should equal "ssh"
      The line 2 of output should equal "-p"
      The line 3 of output should equal "2222"
      The line 4 of output should equal "user@host"
    End

    It "ssh プロセスが無い場合は exit 1"
      extract_from_no_ssh() { extract_ssh_argv_from_process_info "$(no_ssh_fixture)"; }
      When call extract_from_no_ssh
      The status should be failure
    End

    It "argv が無い場合は cmdline を空白分割してフォールバックする"
      extract_from_cmdline() { extract_ssh_argv_from_process_info "$(cmdline_only_fixture)"; }
      When call extract_from_cmdline
      The line 1 of output should equal "ssh"
      The line 2 of output should equal "user@host"
    End
  End

  Describe "validate_paths"
    setup_fixtures() {
      FIXTURE_DIR=$(mktemp -d)
      touch "$FIXTURE_DIR/plain.txt" "$FIXTURE_DIR/My File.txt"
    }

    cleanup_fixtures() {
      rm -rf "$FIXTURE_DIR"
    }

    Before "setup_fixtures"
    After "cleanup_fixtures"

    It "存在するパスを stdout に返す（スペース入り含む）"
      validate_two() { validate_paths "$FIXTURE_DIR/plain.txt" "$FIXTURE_DIR/My File.txt"; }
      When call validate_two
      The line 1 of output should equal "$FIXTURE_DIR/plain.txt"
      The line 2 of output should equal "$FIXTURE_DIR/My File.txt"
      The status should be success
    End

    It "存在しないパスは stderr に出し、混在時は stdout に有効分のみ返す"
      validate_mixed() { validate_paths "$FIXTURE_DIR/plain.txt" "$FIXTURE_DIR/nope.txt"; }
      When call validate_mixed
      The output should equal "$FIXTURE_DIR/plain.txt"
      The stderr should include "nope.txt"
      The status should be success
    End

    It "全パスが存在しない場合は exit 1"
      validate_none() { validate_paths "$FIXTURE_DIR/nope1.txt" "$FIXTURE_DIR/nope2.txt"; }
      When call validate_none
      The stderr should include "nope1.txt"
      The status should be failure
    End
  End

  Describe "quote_for_remote"
    It "スペースを含むパスをシェルセーフに引用する"
      When call quote_for_remote "uploads/My File.txt"
      The output should equal "uploads/My\\ File.txt"
    End

    It "通常のパスはそのまま返す"
      When call quote_for_remote "uploads/plain.txt"
      The output should equal "uploads/plain.txt"
    End
  End
End

Describe "drop-upload/scripts/overlay.sh"
  OVERLAY="$SHELLSPEC_PROJECT_ROOT/config/herdr/plugins/drop-upload/scripts/overlay.sh"

  setup_overlay_env() {
    MOCK_LOG=$(mktemp)
    STATE_DIR=$(mktemp -d)
    CONFIG_DIR=$(mktemp -d)
    FIXTURE_DIR=$(mktemp -d)
    DROP_FILE="$FIXTURE_DIR/drop.txt"
    touch "$DROP_FILE" "$FIXTURE_DIR/My File.txt"
    printf 'w1:p9\n' > "$STATE_DIR/target_pane"
    cat > "$STATE_DIR/process_info.json" <<'JSON'
{"id":"cli:pane:process_info","result":{"process_info":{"foreground_processes":[{"argv":["ssh","-p","2222","user@host"],"argv0":"ssh","cmdline":"ssh -p 2222 user@host","name":"ssh","pid":2}],"pane_id":"w1:p9","shell_pid":1}}}
JSON
    export MOCK_LOG HERDR_ENV=1
    export HERDR_PLUGIN_STATE_DIR="$STATE_DIR"
    export HERDR_PLUGIN_CONFIG_DIR="$CONFIG_DIR"
  }

  cleanup_overlay_env() {
    rm -rf "$MOCK_LOG" "$STATE_DIR" "$CONFIG_DIR" "$FIXTURE_DIR"
  }

  Before "setup_overlay_env"
  After "cleanup_overlay_env"

  Mock scp
    echo "scp $*" >> "$MOCK_LOG"
    exit "${SCP_EXIT:-0}"
  End

  Mock ssh
    echo "ssh $*" >> "$MOCK_LOG"
    exit 0
  End

  Mock herdr
    echo "herdr $*" >> "$MOCK_LOG"
    case "$1 ${2:-}" in
      "pane process-info") exit "${PANE_ALIVE_EXIT:-0}" ;;
      *) exit 0 ;;
    esac
  End

  It "1ファイルの正常転送: scp -P 2222 で転送し対象ペインへリモートパスを send-text する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    When run "$OVERLAY"
    The status should be success
    The output should include "uploads/drop.txt"
    The contents of file "$MOCK_LOG" should include "scp"
    The contents of file "$MOCK_LOG" should include "-P 2222"
    The contents of file "$MOCK_LOG" should include "user@host:uploads/"
    The contents of file "$MOCK_LOG" should include "pane send-text w1:p9 uploads/drop.txt"
  End

  It "初回転送前にリモートディレクトリを ssh mkdir -p で作成する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    When run "$OVERLAY"
    The status should be success
    The output should include "uploads/drop.txt"
    The contents of file "$MOCK_LOG" should include "ssh -p 2222 user@host"
    The contents of file "$MOCK_LOG" should include "mkdir -p"
  End

  It "スペース入りパスはシェルセーフに引用して send-text する"
    Data:expand
      #|"$FIXTURE_DIR/My File.txt"
      #|
    End
    When run "$OVERLAY"
    The status should be success
    The output should include "uploaded: uploads/My\\ File.txt"
    The contents of file "$MOCK_LOG" should include "pane send-text w1:p9 uploads/My\\ File.txt"
  End

  It "scp 失敗時は send-text せずエラー表示してループ継続、空行で正常終了する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    run_scp_fail() { SCP_EXIT=1 "$OVERLAY"; }
    When run run_scp_fail
    The status should be success
    The output should include "failed"
    The stderr should include "scp"
    The contents of file "$MOCK_LOG" should not include "send-text"
  End

  It "scp 失敗時は実際の exit code を stderr に表示する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    run_scp_fail42() { SCP_EXIT=42 "$OVERLAY"; }
    When run run_scp_fail42
    The status should be success
    The output should include "failed"
    The stderr should include "42"
    The contents of file "$MOCK_LOG" should not include "send-text"
  End

  It "settings.conf の不正な remote_dir は警告してデフォルト uploads にフォールバックする"
    Data:expand
      #|$DROP_FILE
      #|
    End
    printf 'remote_dir=$(touch /tmp/pwn)\n' > "$CONFIG_DIR/settings.conf"
    When run "$OVERLAY"
    The status should be success
    The output should include "uploads/drop.txt"
    The stderr should include "remote_dir"
    The contents of file "$MOCK_LOG" should include "user@host:uploads/"
  End

  It "settings.conf の remote_dir にパストラバーサル (..) があれば拒否してデフォルトにフォールバックする"
    Data:expand
      #|$DROP_FILE
      #|
    End
    printf 'remote_dir=../../etc\n' > "$CONFIG_DIR/settings.conf"
    When run "$OVERLAY"
    The status should be success
    The output should include "uploads/drop.txt"
    The stderr should include "remote_dir"
    The contents of file "$MOCK_LOG" should include "user@host:uploads/"
  End

  It "q で即キャンセル: scp も send-text も呼ばれない"
    Data
      #|q
    End
    When run "$OVERLAY"
    The status should be success
    The output should include "── drop-upload ──"
    The contents of file "$MOCK_LOG" should not include "scp"
    The contents of file "$MOCK_LOG" should not include "send-text"
  End

  It "対象ペイン消滅時は send-text せずリモートパスを表示する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    run_pane_dead() { PANE_ALIVE_EXIT=1 "$OVERLAY"; }
    When run run_pane_dead
    The status should be success
    The output should include "uploads/drop.txt"
    The contents of file "$MOCK_LOG" should not include "send-text"
  End

  It "settings.conf の remote_dir を反映する"
    Data:expand
      #|$DROP_FILE
      #|
    End
    printf 'remote_dir=inbox\n' > "$CONFIG_DIR/settings.conf"
    When run "$OVERLAY"
    The status should be success
    The output should include "uploaded: inbox/drop.txt"
    The contents of file "$MOCK_LOG" should include "user@host:inbox/"
    The contents of file "$MOCK_LOG" should include "pane send-text w1:p9 inbox/drop.txt"
  End

  It "HERDR_PLUGIN_STATE_DIR 未設定なら exit 1 で手動手順を案内する"
    run_no_state() { env -u HERDR_PLUGIN_STATE_DIR "$OVERLAY"; }
    When run run_no_state
    The status should be failure
    The stderr should include "scp"
  End
End
