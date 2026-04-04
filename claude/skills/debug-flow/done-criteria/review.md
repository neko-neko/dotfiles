---
name: review
max_retries: 3
audit: required
---

## Operations

### REV-OP1: Code Review が全6観点で実行された
- **layer**: verification
- **check**: automated
- **verification**: 6観点（quality, security, performance, test, ai-antipattern, impact）の実行記録を確認
- **pass_condition**: 6観点全ての実行記録が存在

### REV-OP2: Test Review が全3観点で実行された（--e2e 時のみ）
- **layer**: verification
- **check**: automated
- **verification**: 3観点（coverage, quality, design-alignment）の実行記録を確認
- **pass_condition**: 3観点全ての実行記録が存在

### REV-OP3: 未コミット変更なし + main から乖離50 commit 以内
- **layer**: verification
- **check**: automated
- **verification**: `git status --porcelain` が空、`git rev-list --count HEAD ^main` が50以下
- **pass_condition**: 未コミット変更0件 AND 乖離50以内

### REV-OP4: impact severity high 以上の findings がユーザー判断を経ている
- **layer**: validation
- **check**: inspection
- **verification**: high/critical findings が修正済み、ユーザー承認の延期、またはユーザー承認の却下のいずれか
- **pass_condition**: ユーザー未確認の延期/却下が 0 件
- **severity**: blocker

## Artifact Validation

### review_findings

additional:
  - question: "設計書の全テスト観点がテストコードでカバーされているか（--e2e 時）"
    severity: blocker

### code_changes

additional: []
