---
phase: 1
phase_name: design
phase_references:
  - references/brainstorming-supplement.md
invoke_agents: []
phase_flags:
  swarm: optional
  linear: optional
---

## 実行手順

1. `references/brainstorming-supplement.md` を Read（事前制約確認）
2. Skill invoke: `superpowers:brainstorming`
   - brainstorming 完了後、設計書が `docs/superpowers/specs/` に生成される
3. Skill invoke: `worktrunk:worktrunk`
   - worktree を作成、設計書をコミット
4. brainstorming → writing-plans と遷移し、実装計画書も生成

### --swarm 時

TeamCreate で "exploration-{feature}" チームを作成:
- メンバー: code-explorer, code-architect, impact-analyzer
- 調査結果を Investigation Record として統合

### --linear 時

design フェーズ開始前に:
1. `/linear-sync` の `resolve_ticket` セクションを Read し実行
2. チケット確定後、`sync_workflow_start` を実行

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| spec_file | file | `docs/superpowers/specs/YYYY-MM-DD-*-design.md` |
| investigation_record | file | worktree 内のドキュメント |

## Phase Summary テンプレート

```yaml
artifacts:
  spec_file:
    type: file
    value: "<spec ファイルパス>"
  investigation_record:
    type: file
    value: "<investigation record パス>"
```
