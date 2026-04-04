---
name: plan
max_retries: 3
audit: required
---

## Operations

（なし — plan フェーズにはフェーズ固有の運用チェックはない）

## Artifact Validation

### implementation_plan

additional:
  - question: "タスク粒度が sub-agent で実行可能か（各タスクのステップ数が10以下、変更対象モジュールが3未満）"
    severity: quality
  - question: "タスク依存関係に循環がなく、依存先タスク ID が全て計画書内に存在するか"
    severity: blocker

### test_cases

additional:
  - question: "各テストケースに Given/When/Then の3要素が全て含まれ、Then 句に検証可能な期待値があるか"
    severity: blocker
