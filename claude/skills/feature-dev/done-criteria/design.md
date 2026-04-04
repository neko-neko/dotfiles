---
name: design
max_retries: 3
audit: required
---

## Operations

### DSN-OP1: worktree 作成済み + ベースラインテスト通過
- **layer**: verification
- **check**: automated
- **verification**:
  1. `git worktree list` で worktree が存在することを確認（出力行数が2以上）
  2. プロジェクトのテストコマンドを実行し exit code が 0 であることを確認
- **pass_condition**: worktree 存在 AND テスト exit code = 0

### DSN-OP2: コードベース並列探索が実行された
- **layer**: verification
- **check**: automated
- **verification**: brainstorming-supplement S1 の3エージェント（code-explorer, code-architect, impact-analyzer）の実行記録を確認
- **pass_condition**: 3エージェント全ての実行記録が存在

## Artifact Validation

### spec_file

additional:
  - question: "代替案が検討され、各案に採用/不採用の理由が付記されているか"
    severity: quality
  - question: "主要な設計判断とその根拠が設計書に記載されているか"
    severity: blocker
  - question: "Investigation Record の6項目（prerequisites, impact_scope, reverse_dependencies, shared_state, implicit_contracts, side_effect_risks）が実質的な内容を持つか"
    severity: blocker
