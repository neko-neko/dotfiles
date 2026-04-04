---
phase: 2
phase_name: spec-review
requires_artifacts:
  - spec_file
phase_references: []
invoke_agents:
  - spec-review-requirements
  - spec-review-design-judgment
  - spec-review-feasibility
  - spec-review-consistency
phase_flags:
  codex: optional
  ui: optional
  iterations: optional
  swarm: optional
---

## 実行手順

1. `requires_artifacts` の `spec_file` を Read
2. Skill invoke: `/spec-review`
   - 引数: spec ファイルパス
   - `--codex` 時: Codex 並列レビュー追加
   - `--ui` 時: spec-review-ui-design エージェント追加
   - `--iterations N` 時: N-way 投票

### --swarm 時

TeamCreate で "spec-review-{feature}" チームを作成:
- メンバー: spec-review-{requirements, design-judgment, feasibility, consistency}
- `--ui` 時: spec-review-ui-design 追加

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
