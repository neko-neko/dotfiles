---
trigger: review_findings
---

# Review Findings Regate Strategy

## 判定ロジック

1. findings の severity を分類
   - blocker あり → regate 必須
   - quality のみ → 件数が threshold (3件) 以上なら regate

2. findings の対象フェーズを判定
   - コード変更が必要 → rewind_to: execute
   - 設計変更が必要 → rewind_to: plan（severity: blocker かつ設計起因のみ）
   - テスト変更のみ → rewind_to: execute

## Rerun チェーン

### rewind_to: execute の場合

1. findings を fix_instruction として execute フェーズに注入
2. verification_chain をフル実行: execute → review → smoke-test（--smoke 時）
3. 各フェーズは通常の Audit Gate を通過する

### rewind_to: plan の場合

1. 設計起因の blocker findings を plan フェーズに注入
2. plan → plan-review → verification_chain (execute → review → smoke-test)

## コンテキスト注入

rewind_to フェーズ進入時、以下を追加コンテキストとして注入:

```yaml
regate_context:
  trigger: review_findings
  source_phase: review
  findings:
    - severity: blocker
      file: <ファイルパス>
      description: <指摘内容>
      fix_suggestion: <修正案>
  attempt: N
```
