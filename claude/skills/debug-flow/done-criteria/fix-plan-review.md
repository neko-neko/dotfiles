---
name: fix-plan-review
max_retries: 3
audit: required
---

## Operations

### FPR-OP1: レビューが全3観点で実行された
- **layer**: verification
- **check**: automated
- **verification**: 3観点（clarity, feasibility, consistency）の実行記録を確認
- **pass_condition**: 3観点全ての実行記録が存在

### FPR-OP2: コンセンサス findings が全て解消済み
- **layer**: verification
- **check**: automated
- **verification**: severity: consensus の findings を抽出し、未解消件数をカウント
- **pass_condition**: 未解消件数 = 0

## Artifact Validation

### fix_plan

additional:
  - question: "計画書と RCA Report の整合性が保たれているか（根本原因、影響範囲、修正方針の一致）"
    severity: blocker
  - question: "各タスクの完了条件が検証可能な形で記述されているか（主観語なし）"
    severity: blocker
