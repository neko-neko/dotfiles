---
phase: 5
phase_name: smoke-test
requires_artifacts:
  - code_changes
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

このフェーズは `--smoke` フラグ指定時のみ有効。未指定時はスキップ。

1. Skill invoke: `/smoke-test`
   - dev サーバー起動
   - アドホックテスト生成・実行
   - VRT 差分チェック
   - E2E 実行 + フレーキー検出

マージ前のローカル最終確認として位置づける。

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| smoke_test_results | file | `smoke-test-report.md` |

## Phase Summary テンプレート

```yaml
artifacts:
  smoke_test_results:
    type: file
    value: "<smoke-test-report.md パス>"
```
