---
phase: 9
phase_name: integrate
requires_artifacts:
  - code_changes
phase_references: []
invoke_agents: []
phase_flags:
  linear: optional
---

## 実行手順

1. Skill invoke: `worktrunk:worktrunk`
2. ユーザーに統合方法を選択してもらう:
   - `wt merge`: worktree をメインブランチにマージ
   - `pr`: PR を作成
   - `branch-keep`: ブランチを保持（マージしない）
   - `discard`: 変更を破棄

### --linear 時

ワークフロー完了後:
1. `/linear-sync` の `sync_complete` を実行
2. チケットステータスを Done に更新
3. Workflow Report Document を最終更新

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| merged_branch | inline | マージ先ブランチ名 |
| pr_url | inline | PR URL（pr 選択時） |

## Phase Summary テンプレート

```yaml
artifacts:
  merged_branch:
    type: inline
    value: "<マージ先ブランチ名 or 'not merged'>"
  pr_url:
    type: inline
    value: "<PR URL or 'N/A'>"
```
