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

## Artifact Validation

### code_changes

additional:
  - question: "Unit Test + Integration Test が計画書の全テストケースに対応して存在するか"
    severity: blocker
  - question: "RCA Report→修正計画→実装の3段トレーサビリティに欠落がなく、計画タスクに対応しない余剰実装がないか"
    severity: blocker
  - question: "reproduction_test が修正後に PASS に転じているか"
    severity: blocker
