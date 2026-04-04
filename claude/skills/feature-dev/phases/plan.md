---
phase: 3
phase_name: plan
requires_artifacts:
  - spec_file
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

1. `requires_artifacts` の `spec_file` を Read
2. Skill invoke: `superpowers:writing-plans`
   - 設計書に基づいて実装計画書を生成
   - 計画書は `docs/superpowers/plans/` に保存される
3. テストケースも計画書内に含まれる

このフェーズは AUTONOMOUS（ユーザー承認なしで自動遷移可能）。

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| implementation_plan | file | `docs/superpowers/plans/YYYY-MM-DD-*-plan.md` |
| test_cases | file | 計画書内に含まれる |

## Phase Summary テンプレート

```yaml
artifacts:
  implementation_plan:
    type: file
    value: "<計画書ファイルパス>"
  test_cases:
    type: file
    value: "<計画書ファイルパス>（計画書に内包）"
```
