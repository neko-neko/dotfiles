---
phase: 2
phase_name: fix-plan
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

1. `rca_report` を Read（engine が artifacts から解決）
2. Skill invoke: `superpowers:writing-plans`
   - RCA Report の Fix Strategy セクションを `docs/plans/*-fix-plan.md` に展開
   - テストケースも `docs/plans/*-test-cases.md` に詳細化
3. 計画書をコミット

このフェーズは AUTONOMOUS（ユーザー承認なしで自動遷移可能）。

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| fix_plan | file | `docs/plans/YYYY-MM-DD-*-fix-plan.md` |

## Phase Summary テンプレート

```yaml
artifacts:
  fix_plan:
    type: file
    value: "<修正計画書ファイルパス>"
```
