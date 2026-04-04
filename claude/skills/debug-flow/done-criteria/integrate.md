---
name: integrate
max_retries: 3
audit: lite
---

## Operations

### INT-OP1: ユーザーが統合方法を選択済み
- **layer**: verification
- **check**: automated
- **verification**: 統合方法の選択値が wt-merge/pr/branch-keep/discard のいずれか
- **pass_condition**: 有効な選択値が存在

### INT-OP2: 選択されたアクションが完了
- **layer**: verification
- **check**: automated
- **verification**: wt-merge→マージコミット存在+worktree削除。pr→PR URL取得成功+worktree削除。branch-keep→ブランチ存在。discard→worktree削除。
- **pass_condition**: 選択された方法に応じた完了条件を満たす

## Artifact Validation

### merged_branch

additional: []
