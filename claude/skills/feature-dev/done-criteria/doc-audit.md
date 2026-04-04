---
phase: 7
name: doc-audit
max_retries: 2
audit: required
---

## Criteria

### D7-01: depends-on パス不存在の解消
- severity: blocker
- verify_type: automated
- verification: `doc-audit.sh --full --json` を再実行し `broken_deps` を確認
- pass_condition: broken_deps 配列の要素数が 0
- fail_diagnosis_hint: 残存する broken path を修正するか、depends-on から削除する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-script-output.json]

### D7-02: depends-on 未宣言の解消
- severity: blocker
- verify_type: automated
- verification: `doc-audit.sh --check-undeclared --json` を再実行し `undeclared_deps` を確認
- pass_condition: undeclared_deps 配列の要素数が 0
- fail_diagnosis_hint: 検出されたパスを depends-on に追加する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-script-output.json]

### D7-03: デッドリンクの解消
- severity: blocker
- verify_type: automated
- verification: `doc-audit.sh --full --json` を再実行し `dead_links` を確認
- pass_condition: dead_links 配列の要素数が 0
- fail_diagnosis_hint: リンク先を修正するか、リンクを削除する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-script-output.json]

### D7-04: 新規/更新ドキュメントの frontmatter 整備
- severity: blocker
- verify_type: automated
- verification:
  1. Phase 7 で作成/更新された md ファイルを git diff --name-only で列挙
  2. 各ファイルの depends-on を parse_depends_on で抽出
  3. depends-on に 1 件以上のパスが宣言されていること
  4. 宣言された全パスがファイルシステム上に存在すること
- pass_condition: 対象 md 全件で depends-on に 1 件以上のパス宣言あり かつ 全パス存在確認済み
- fail_diagnosis_hint: frontmatter に depends-on を追加し、実在するパスを宣言する
- depends_on_artifacts: [artifacts/diff/phase-7-doc.diff]

### D7-05: doc-check 実行完了
- severity: blocker
- verify_type: automated
- verification:
  1. doc-check 実行ログを確認
  2. 終了コードが 0（影響なし）であること、または全影響ドキュメントの status を確認
- pass_condition: doc-check 終了コード 0、または全影響ドキュメントの status が "updated" or "skipped"（ユーザー明示選択）
- fail_diagnosis_hint: doc-check を再実行し、未処理のドキュメントを処理する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-doc-check.log]

### D7-06: 孤立ドキュメント処理
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の orphaned_docs カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "deleted", "linked", "skipped" のいずれかであること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: orphaned findings 全件の status ∈ {"deleted", "linked", "skipped"}
- fail_diagnosis_hint: 未処理の孤立ドキュメントを削除、リンク追加、またはスキップ判断する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: B のみ

### D7-07: 陳腐化ドキュメント処理
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の stale_signals カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "updated" の場合、対象 doc の git log --format=%at -1 が Phase 7 開始タイムスタンプ以降であること
  4. status が "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: stale findings 全件の status ∈ {"updated", "skipped"} かつ "updated" の doc は最終コミットが Phase 7 開始以降
- fail_diagnosis_hint: 陳腐化ドキュメントの内容を更新するか、スキップ判断する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: B のみ

### D7-08: ドキュメント間一貫性
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の coherence カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed" または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: coherence findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: 矛盾箇所を統一するか、重複ドキュメントを統合する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: B のみ

### D7-09: ドキュメント欠落対応
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の missing_documentation カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed"（新規作成済み）または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: coverage findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: 欠落ドキュメントを新規作成するか、スキップ判断する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: A は git diff 範囲、B は全体

### D7-10: 未文書化ビジネスルール対応
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の undocumented_business_rule カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed" または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: business-rule findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: ビジネスルールを既存ドキュメントに追記するか、新規ドキュメントを作成する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: B のみ

### D7-11: 未文書化設計判断対応
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の undocumented_design_decision カテゴリの findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed" または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: architecture findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: 設計判断を CLAUDE.md または ADR に追記する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: B のみ

### D7-12: README/CONTRIBUTING/CHANGELOG 整合
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の readme-analyzer findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed" または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: readme findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: README 等のメタドキュメントを更新する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: A は git diff 影響分、B は全体

### D7-13: CLAUDE.md/規約ファイル整合
- severity: quality
- verify_type: inspection
- verification:
  1. doc-audit-report.json の claude-md-analyzer findings を列挙
  2. 各 finding の status を確認
  3. status が "fixed" または "skipped" であること
  4. "skipped" の場合、user_decision フィールドが存在すること
- pass_condition: claude-md findings 全件の status ∈ {"fixed", "skipped"} かつ "skipped" にユーザー承認記録あり
- fail_diagnosis_hint: CLAUDE.md の規約を実コードに合わせて更新する
- depends_on_artifacts: [artifacts/doc-audit/phase-7-report.json]
- scope: A は git diff 影響分、B は全体

## Observation Collection

phase-auditor は verdict 出力時に observations[] を必ず含めること。
PASS 判定の criteria でも quality/warning レベルの所見があれば記録する。
observations は project-state.json の phase_observations[] に蓄積される。
