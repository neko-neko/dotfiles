---
trigger: test_failure
---

# Test Failure Regate Strategy

## 判定ロジック

1. 失敗の種類を分類
   - 既存テストの regression → 実装コードの修正が必要
   - 新規テストの failure → テストまたは実装コードの修正が必要
   - flaky test → 再実行で確認（max 2回）

2. 失敗の原因箇所を特定
   - テストコード自体の問題 → テスト修正
   - 実装コードの問題 → 実装修正

## Rerun チェーン

1. テスト失敗ログを fix_instruction として execute フェーズに注入
2. verification_chain をフル実行: execute → review → smoke-test（--smoke 時）
3. 各フェーズは通常の Audit Gate を通過する

## Flaky 検出時

1. 同一テストが2回の再実行で成功/失敗が交互 → flaky と判定
2. flaky テストを evidence に記録
3. テスト修正を試行
4. 修正不可なら concern として後続フェーズに伝播:

```yaml
concerns:
  - target_phase: integrate
    content: "flaky test detected: <テスト名>. 要調査"
```

## コンテキスト注入

```yaml
regate_context:
  trigger: test_failure
  source_phase: execute | smoke-test
  failures:
    - test_name: <テスト名>
      error: <エラーメッセージ>
      file: <テストファイルパス>
      type: regression | new_failure | flaky
  attempt: N
```
