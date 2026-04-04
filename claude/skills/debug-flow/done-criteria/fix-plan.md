---
name: fix-plan
max_retries: 3
audit: required
---

## Operations

（なし）

## Artifact Validation

### fix_plan

additional:
  - question: "Fix Strategy の全項目がタスクに分解されているか"
    severity: blocker
  - question: "タスク依存関係に循環がなく、依存先タスク ID が全て計画書内に存在するか"
    severity: blocker

### test_cases

additional:
  - question: "各テストケースに Given/When/Then の3要素が全て含まれ、Then 句に検証可能な期待値があるか"
    severity: blocker
