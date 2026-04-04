# Semantic Phase Naming

## Summary

pipeline.yml で定義されたセマンティック ID（`design`, `execute`, `review` 等）が存在するにもかかわらず、
ファイル名・アーティファクトパス・criteria ID がステップ番号（`phase-01`, `phase-05` 等）に依存している。
パイプラインの組み換え可能性を前提とし、ポジション番号へのハードコーディングを全て排除する。

## Scope

### 対象

- feature-dev, debug-flow, doc-audit の `phases/`, `done-criteria/`, `pipeline.yml`
- done-criteria 内のアーティファクトパス・criteria ID・frontmatter・prose
- handover, continue の SKILL.md 内のパイプラインフェーズ表示
- linear-sync テンプレートのフェーズ列
- feature-dev/debug-flow SKILL.md のフェーズ参照

### 対象外

spec-review, code-review, test-review, implementation-review, triage, linear-add, linear-cleanup, linear-refresh の SKILL.md 内「Phase 1」「Phase 2」等。
これらはパイプラインフェーズではなく各スキル内部のワークフローステップであり、変更不要。

## Design

### 1. ファイルリネーム

`phase-NN-<id>.md` → `<id>.md`

**feature-dev phases/ (9ファイル):**

| Before | After |
|---|---|
| `phase-01-design.md` | `design.md` |
| `phase-02-spec-review.md` | `spec-review.md` |
| `phase-03-plan.md` | `plan.md` |
| `phase-04-plan-review.md` | `plan-review.md` |
| `phase-05-execute.md` | `execute.md` |
| `phase-06-accept-test.md` | `accept-test.md` |
| `phase-07-doc-audit.md` | `doc-audit.md` |
| `phase-08-review.md` | `review.md` |
| `phase-09-integrate.md` | `integrate.md` |

feature-dev done-criteria/ も同一パターン（9ファイル）。

**debug-flow phases/ (8ファイル):**

| Before | After |
|---|---|
| `phase-01-rca.md` | `rca.md` |
| `phase-02-fix-plan.md` | `fix-plan.md` |
| `phase-03-fix-plan-review.md` | `fix-plan-review.md` |
| `phase-04-execute.md` | `execute.md` |
| `phase-05-accept-test.md` | `accept-test.md` |
| `phase-06-doc-audit.md` | `doc-audit.md` |
| `phase-07-review.md` | `review.md` |
| `phase-08-integrate.md` | `integrate.md` |

debug-flow done-criteria/ も同一パターン（8ファイル）。

**doc-audit done-criteria/ (1ファイル):**

| Before | After |
|---|---|
| `phase-6-doc-audit.md` | `doc-audit.md` |

**リネーム合計: 35ファイル**

### 2. pipeline.yml パス更新

`phase_file` と `done_criteria` を `<id>.md` 形式に統一。

```yaml
# Before
- id: design
  phase_file: phases/phase-01-design.md
  done_criteria: done-criteria/phase-01-design.md

# After
- id: design
  phase_file: phases/design.md
  done_criteria: done-criteria/design.md
```

### 3. done-criteria frontmatter

`phase: N` フィールドを削除。`name:` が既にセマンティック ID を持つ。

```yaml
# Before
phase: 8
name: review
max_retries: 3
audit: required

# After
name: review
max_retries: 3
audit: required
```

### 4. Criteria ID

3文字セマンティック略称に統一。

| Phase ID | Abbreviation | Example |
|---|---|---|
| design | DSN | `DSN-01` |
| spec-review | SPR | `SPR-01` |
| plan | PLN | `PLN-01` |
| plan-review | PLR | `PLR-01` |
| execute | EXE | `EXE-01` |
| accept-test | ACT | `ACT-01` |
| doc-audit | DOC | `DOC-01` |
| review | REV | `REV-C01` (code), `REV-T01` (test) |
| integrate | INT | `INT-01` |
| rca | RCA | `RCA-01` |
| fix-plan | FPL | `FPL-01` |
| fix-plan-review | FPR | `FPR-01` |

### 5. アーティファクトパス

番号プレフィックスを除去。ディレクトリがカテゴリを示すため冗長。

| Before | After |
|---|---|
| `artifacts/doc-audit/phase-6-script-output.json` | `artifacts/doc-audit/script-output.json` |
| `artifacts/doc-audit/phase-6-report.json` | `artifacts/doc-audit/report.json` |
| `artifacts/doc-audit/phase-6-doc-check.log` | `artifacts/doc-audit/doc-check.log` |
| `artifacts/diff/phase-6-doc.diff` | `artifacts/diff/doc-audit.diff` |
| `artifacts/reviews/phase-2-review.json` | `artifacts/reviews/spec-review.json` |
| `artifacts/reviews/phase-3-review.json` | `artifacts/reviews/fix-plan-review.json` |
| `artifacts/reviews/phase-4-review.json` | `artifacts/reviews/plan-review.json` |
| `artifacts/reviews/phase-8-code-review.json` | `artifacts/reviews/code-review.json` |
| `artifacts/reviews/phase-8-test-review.json` | `artifacts/reviews/test-review.json` |
| `artifacts/reviews/phase-7-code-review.json` | `artifacts/reviews/code-review.json` |
| `artifacts/reviews/phase-7-test-review.json` | `artifacts/reviews/test-review.json` |

feature-dev の doc-audit 系（`phase-7-*`）も同パターンで `artifacts/doc-audit/*`, `artifacts/diff/doc-audit.diff` に統一。

### 6. Prose（本文中の "Phase N" 参照）

done-criteria 内の prose をセマンティック名に置換。

| Pattern | Replacement |
|---|---|
| `Phase N で作成/更新された` | `doc-audit フェーズで作成/更新された`（等、対応するフェーズ名） |
| `Phase N 開始タイムスタンプ以降` | `<phase-id> フェーズ開始タイムスタンプ以降` |
| `Phase N Executor` | `当フェーズ Executor`（自己参照）/ `<phase-id> Executor`（他フェーズ参照） |
| `Phase N (Name)` in forward_check | `<phase-id>`（例: `spec-review`） |

### 7. handover/SKILL.md

project-state.json スキーマ:

```json
// Before
"phase_summaries": {
    "1": "phase-summaries/phase-01-design.yml",
    "2": "phase-summaries/phase-02-spec-review.yml"
}
"last_synced_phase": 5

// After
"phase_summaries": {
    "design": "phase-summaries/design.yml",
    "spec-review": "phase-summaries/spec-review.yml"
}
"last_synced_phase": "execute"
```

進捗表示:

```
// Before
- [Phase 1] Design ✅ (spec: <path>)
- [Phase 2] Spec Review ✅ (findings: 0 blocker)

// After
- [design] ✅ (spec: <path>)
- [spec-review] ✅ (findings: 0 blocker)
```

### 8. continue/SKILL.md

```
// Before
Phase 1 (design) ✅
Phase 2 (spec-review) ✅
→ Current: Phase 4 (plan-review)

// After
design ✅
spec-review ✅
→ Current: plan-review
```

### 9. feature-dev/SKILL.md, debug-flow/SKILL.md

- `Phase 1 (design) から開始` → `design フェーズから開始`

### 10. linear-sync/templates/document.md

番号ベースのテンプレート変数をセマンティック ID ベースに置換。

## Impact Summary

| Category | File Count |
|---|---|
| File renames | 35 |
| pipeline.yml (content edit) | 2 |
| done-criteria (content edit) | 17 |
| SKILL.md (content edit) | 4 (handover, continue, feature-dev, debug-flow) |
| Template (content edit) | 1 (linear-sync) |
| doc-audit done-criteria | 1 |
| **Total** | ~45 files |
