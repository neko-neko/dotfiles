---
name: spec-review
max_retries: 3
audit: required
---

## Operations

### SPR-OP1: レビューが全4観点で実行された
- **layer**: verification
- **check**: automated
- **verification**: レビューログから4観点（requirements, design-judgment, feasibility, consistency）の実行記録を確認
- **pass_condition**: 4観点全ての実行記録が存在

### SPR-OP2: コンセンサス findings が全て解消済み
- **layer**: verification
- **check**: automated
- **verification**: severity: consensus の findings を抽出し、未解消件数をカウント
- **pass_condition**: 未解消件数 = 0

## Artifact Validation

### spec_file

additional:
  - question: "レビュー指摘に基づく修正が設計書に正しく反映されているか"
    severity: blocker
  - question: "修正後の設計書内で相互参照（要件番号、コンポーネント名、ファイルパス）が整合しているか"
    severity: blocker
  - question: "次フェーズ（plan）の入力として、要件が一意に列挙可能な粒度まで具体化されているか"
    severity: blocker
