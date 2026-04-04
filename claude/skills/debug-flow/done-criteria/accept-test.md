---
name: accept-test
max_retries: 3
audit: required
---

## Operations

### ACT-OP1: 全 Acceptance Test ステップが PASS
- **layer**: verification
- **check**: automated
- **verification**: テスト結果ファイルの全ステップが PASS であることを確認
- **pass_condition**: FAIL ステップが 0 件

### ACT-OP2: flaky test が未検出または報告済み
- **layer**: verification
- **check**: automated
- **verification**: 同一ステップの再実行で結果が変わったケースを検出
- **pass_condition**: flaky 未検出、または全件が報告リストに記録済み

### ACT-OP3: テスト実行証跡が有効
- **layer**: verification
- **check**: automated
- **verification**: accept-test-report.md の存在、プロジェクト種別に応じた証跡（スクリーンショット、ログ等）の存在を確認
- **pass_condition**: レポート + 証跡が存在

## Artifact Validation

### accept_test_results

additional: []
