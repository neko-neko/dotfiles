---
name: execute
max_retries: 3
audit: required
---

## Operations

### EXE-OP1: 全タスクに対応するコード変更が存在する
- **layer**: validation
- **check**: inspection
- **verification**: 計画書の全タスク ID と git diff --name-only の変更ファイルを照合
- **pass_condition**: コード変更のないタスク ID が 0 件

### EXE-OP2: 実装がコンポーネント境界を遵守している
- **layer**: validation
- **check**: inspection
- **verification**: 設計書のコンポーネント境界を越える新規直接依存（import/require）がないか確認
- **pass_condition**: 境界違反の新規依存が 0 件
- **severity**: quality

## Artifact Validation

### code_changes

additional:
  - question: "Unit Test + Integration Test が計画書の全テストケースに対応して存在するか"
    severity: blocker
  - question: "設計書→計画書→実装の3段トレーサビリティに欠落がなく、計画書タスクに対応しない余剰実装がないか"
    severity: blocker
  - question: "テストケースが要件カバレッジ（正常系・異常系・境界値の各カテゴリ1件以上）、影響範囲の網羅性、テスト階層（Unit + Integration）を満たすか"
    severity: blocker
