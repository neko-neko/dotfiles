Describe "ts-serve"
  TS_SERVE="$SHELLSPEC_PROJECT_ROOT/bin/ts-serve"

  setup_mock_log() {
    MOCK_LOG=$(mktemp)
    export MOCK_LOG
  }

  cleanup_mock_log() {
    rm -f "$MOCK_LOG"
  }

  Before "setup_mock_log"
  After "cleanup_mock_log"

  Describe "正常系（tailscale モック）"
    Mock tailscale
      echo "$*" >> "$MOCK_LOG"
      case "$1 ${2:-}" in
        "serve status") echo "no serve config" ;;
        "serve --bg") exit 0 ;;
        "serve reset") exit 0 ;;
        "status --json") printf '{"Self":{"DNSName":"mac-mini.tail9c5817.ts.net."}}\n' ;;
        *) exit 0 ;;
      esac
    End

    It "引数なしで serve status を表示する"
      run_status() { "$TS_SERVE"; }
      When run run_status
      The status should be success
      The output should include "no serve config"
      The contents of file "$MOCK_LOG" should include "serve status"
    End

    It "--status で serve status を表示する"
      run_status_flag() { "$TS_SERVE" --status; }
      When run run_status_flag
      The status should be success
      The output should include "no serve config"
    End

    It "ポート指定で serve --bg を実行し公開 URL を表示する（DNSName 末尾ドット除去）"
      run_serve() { "$TS_SERVE" 3000; }
      When run run_serve
      The status should be success
      The output should include "https://mac-mini.tail9c5817.ts.net/"
      The contents of file "$MOCK_LOG" should include "serve --bg 3000"
    End

    It "--off で serve reset を実行し status を表示する"
      run_off() { "$TS_SERVE" --off; }
      When run run_off
      The status should be success
      The output should include "no serve config"
      The contents of file "$MOCK_LOG" should include "serve reset"
    End

    It "-h で usage を表示して正常終了する"
      run_help() { "$TS_SERVE" -h; }
      When run run_help
      The status should be success
      The output should include "Usage:"
    End
  End

  Describe "ポート引数の検証（tailscale serve は呼ばれない）"
    Mock tailscale
      echo "$*" >> "$MOCK_LOG"
      exit 0
    End

    It "数値でないポートは exit 1"
      run_invalid() { "$TS_SERVE" abc; }
      When run run_invalid
      The status should be failure
      The stderr should include "1-65535"
      The contents of file "$MOCK_LOG" should not include "serve"
    End

    It "ポート 0 は exit 1"
      run_zero() { "$TS_SERVE" 0; }
      When run run_zero
      The status should be failure
      The stderr should include "1-65535"
    End

    It "ポート 65536 は exit 1"
      run_over() { "$TS_SERVE" 65536; }
      When run run_over
      The status should be failure
      The stderr should include "1-65535"
    End

    It "先頭ゼロ付きポート（08）は exit 1（8進数バイパス防止）"
      run_leading_zero() { "$TS_SERVE" 08; }
      When run run_leading_zero
      The status should be failure
      The stderr should include "1-65535"
      The contents of file "$MOCK_LOG" should not include "serve"
    End

    It "先頭ゼロ付きポート（007）は exit 1"
      run_octal() { "$TS_SERVE" 007; }
      When run run_octal
      The status should be failure
      The stderr should include "1-65535"
    End

    It "余剰引数は usage を stderr に出して exit 1"
      run_extra() { "$TS_SERVE" 3000 extra; }
      When run run_extra
      The status should be failure
      The stderr should include "Usage:"
      The contents of file "$MOCK_LOG" should not include "serve"
    End

    It "未知のオプションは usage を stderr に出して exit 1"
      run_unknown() { "$TS_SERVE" --foo; }
      When run run_unknown
      The status should be failure
      The stderr should include "Usage:"
    End
  End

  Describe "HTTPS 証明書エラー"
    Mock tailscale
      echo "$*" >> "$MOCK_LOG"
      case "$1 ${2:-}" in
        "serve --bg")
          echo "error: HTTPS is not enabled on this tailnet" >&2
          exit 1
          ;;
        *) exit 0 ;;
      esac
    End

    It "cert エラーを検出して有効化手順を stderr に案内する"
      run_cert_error() { "$TS_SERVE" 3000; }
      When run run_cert_error
      The status should be failure
      The stderr should include "HTTPS"
      The stderr should include "https://login.tailscale.com/admin/dns"
    End
  End

  Describe "tailscale 不在"
    It "tailscale が見つからなければ brew install を案内して exit 1"
      run_no_tailscale() { PATH="/usr/bin:/bin" "$TS_SERVE" 3000; }
      When run run_no_tailscale
      The status should be failure
      The stderr should include "brew install tailscale"
    End
  End
End
