---
phase: 6
phase_name: doc-audit
phase_references: []
invoke_agents: []
phase_flags: {}
---

## 実行手順

このフェーズは `--doc` フラグ指定時のみ有効。未指定時はスキップ。

1. Skill invoke: `/doc-audit`
   - コード変更に影響を受けるドキュメントを検出・更新
2. Skill invoke: `/doc-check`
   - md ファイルの depends-on と git diff を突合し影響範囲を特定

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| doc_audit_report | file | `doc-audit-report.json` |

## Phase Summary テンプレート

```yaml
artifacts:
  doc_audit_report:
    type: file
    value: "<レポートファイルパス>"
```
