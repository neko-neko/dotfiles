---
name: rca
max_retries: 3
audit: required
---

## Operations

### RCA-OP1: worktree 作成済み + ベースラインテスト通過
- **layer**: verification
- **check**: automated
- **verification**: git worktree list + テストコマンド実行
- **pass_condition**: worktree 存在 AND テスト exit code = 0

### RCA-OP2: RCA Report + 再現テストが git commit 済み
- **layer**: verification
- **check**: automated
- **verification**: git status --porcelain で対象ファイルが未コミットリストに含まれない
- **pass_condition**: 未コミット変更に RCA Report/再現テストが含まれない

## Artifact Validation

### rca_report

additional:
  - question: "Investigation Record の4サブセクション（Code Flow Trace, Architecture Context, Impact Scope, Symmetry Check）が実質的な内容を持つか"
    severity: blocker
  - question: "根本原因がファイルパス+行番号+メカニズムの具体性で記述されているか"
    severity: quality
  - question: "除外仮説が記録されているか（仮説+検証方法+棄却理由の3要素）"
    severity: blocker
  - question: "Symmetry Check で非対称性リスクがある場合、対パスの修正必要性が記載されているか"
    severity: blocker
  - question: "Evidence Plan セクションに、type と location を伴う具体的な evidence エントリが最低 1 項目記述されているか"
    severity: blocker

### reproduction_test

additional: []
