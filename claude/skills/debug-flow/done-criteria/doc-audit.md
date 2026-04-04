---
name: doc-audit
max_retries: 2
audit: required
---

## Operations

### DOC-OP1: depends-on パス不存在の解消
- **layer**: verification
- **check**: automated
- **verification**: `doc-audit.sh --full --json` の broken_deps が空

### DOC-OP2: depends-on 未宣言の解消
- **layer**: verification
- **check**: automated
- **verification**: `doc-audit.sh --check-undeclared --json` の undeclared_deps が空

### DOC-OP3: デッドリンクの解消
- **layer**: verification
- **check**: automated
- **verification**: `doc-audit.sh --full --json` の dead_links が空

### DOC-OP4: 新規/更新ドキュメントの frontmatter 整備
- **layer**: verification
- **check**: automated
- **verification**: 対象 md 全件で depends-on に1件以上のパス宣言あり、全パス存在確認済み

### DOC-OP5: doc-check 実行完了
- **layer**: verification
- **check**: automated
- **verification**: doc-check 終了コード 0、または全影響ドキュメントの status が updated/skipped

### DOC-OP6: 孤立ドキュメント処理
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: orphaned_docs findings の status が deleted/linked/skipped のいずれか

### DOC-OP7: 陳腐化ドキュメント処理
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: stale_signals findings が updated/skipped

### DOC-OP8: ドキュメント間一貫性
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: coherence findings が fixed/skipped

### DOC-OP9: ドキュメント欠落対応
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: missing_documentation findings が fixed/skipped

### DOC-OP10: 未文書化ビジネスルール対応
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: undocumented_business_rule findings が fixed/skipped

### DOC-OP11: 未文書化設計判断対応
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: undocumented_design_decision findings が fixed/skipped

### DOC-OP12: README/CONTRIBUTING/CHANGELOG 整合
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: readme-analyzer findings が fixed/skipped

### DOC-OP13: CLAUDE.md/規約ファイル整合
- **layer**: validation
- **check**: inspection
- **severity**: quality
- **verification**: claude-md-analyzer findings が fixed/skipped

## Artifact Validation

### doc_audit_report

additional: []
