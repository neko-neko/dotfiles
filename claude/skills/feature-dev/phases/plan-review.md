---
phase: 4
phase_name: plan-review
phase_references: []
invoke_agents:
  - implementation-review-clarity
  - implementation-review-feasibility
  - implementation-review-consistency
phase_flags:
  codex: optional
  ui: optional
  iterations: optional
  swarm: optional
---

## 実行手順

1. `implementation_plan` と `spec_file` を Read（engine が artifacts から解決）
2. Skill invoke: `/implementation-review`
   - 引数: 計画書ファイルパス
   - `--codex` 時: Codex adversarial-review 追加
   - `--ui` 時: implementation-review-ui-spec エージェント追加
   - `--iterations N` 時: N-way 投票

### --swarm 時

TeamCreate で "plan-review-{feature}" チームを作成:
- メンバー: implementation-review-{clarity, feasibility, consistency}
- `--ui` 時: implementation-review-ui-spec 追加

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| review_report | inline | Phase Summary に含める |

## Phase Summary テンプレート

```yaml
artifacts:
  review_report:
    type: inline
    value: "<findings 件数、severity 分布、verdict>"
```
