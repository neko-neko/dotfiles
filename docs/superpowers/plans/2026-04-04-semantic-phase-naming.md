# Semantic Phase Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** パイプラインのポジション番号（phase-01, phase-05 等）を全て排除し、セマンティック ID ベースのファイル名・パス・IDに統一する。

**Architecture:** feature-dev / debug-flow / doc-audit の phases/, done-criteria/ ファイルをリネームし、pipeline.yml のパス参照、done-criteria 内の frontmatter・criteria ID・アーティファクトパス・prose、及び外部参照（handover, continue, linear-sync, SKILL.md）を全て更新する。

**Tech Stack:** git mv, Edit tool, Grep（verification）

**Spec:** `docs/superpowers/specs/2026-04-04-semantic-phase-naming-design.md`

---

## Criteria ID Abbreviation Table

全タスクで参照する略称マッピング:

| Phase ID | Abbr | Pipeline |
|---|---|---|
| design | DSN | feature-dev |
| spec-review | SPR | feature-dev |
| plan | PLN | feature-dev |
| plan-review | PLR | feature-dev |
| execute | EXE | both |
| accept-test | ACT | both |
| doc-audit | DOC | both |
| review | REV | both |
| integrate | INT | both |
| rca | RCA | debug-flow |
| fix-plan | FPL | debug-flow |
| fix-plan-review | FPR | debug-flow |

---

### Task 1: feature-dev ファイルリネーム + pipeline.yml 更新

**Files:**
- Rename: `claude/skills/feature-dev/phases/phase-*.md` (9 files)
- Rename: `claude/skills/feature-dev/done-criteria/phase-*.md` (9 files)
- Modify: `claude/skills/feature-dev/pipeline.yml`

- [ ] **Step 1: phases/ の 9 ファイルをリネーム**

```bash
cd /Users/nishikataseiichi/.dotfiles
git mv claude/skills/feature-dev/phases/phase-01-design.md claude/skills/feature-dev/phases/design.md
git mv claude/skills/feature-dev/phases/phase-02-spec-review.md claude/skills/feature-dev/phases/spec-review.md
git mv claude/skills/feature-dev/phases/phase-03-plan.md claude/skills/feature-dev/phases/plan.md
git mv claude/skills/feature-dev/phases/phase-04-plan-review.md claude/skills/feature-dev/phases/plan-review.md
git mv claude/skills/feature-dev/phases/phase-05-execute.md claude/skills/feature-dev/phases/execute.md
git mv claude/skills/feature-dev/phases/phase-06-accept-test.md claude/skills/feature-dev/phases/accept-test.md
git mv claude/skills/feature-dev/phases/phase-07-doc-audit.md claude/skills/feature-dev/phases/doc-audit.md
git mv claude/skills/feature-dev/phases/phase-08-review.md claude/skills/feature-dev/phases/review.md
git mv claude/skills/feature-dev/phases/phase-09-integrate.md claude/skills/feature-dev/phases/integrate.md
```

- [ ] **Step 2: done-criteria/ の 9 ファイルをリネーム**

```bash
git mv claude/skills/feature-dev/done-criteria/phase-01-design.md claude/skills/feature-dev/done-criteria/design.md
git mv claude/skills/feature-dev/done-criteria/phase-02-spec-review.md claude/skills/feature-dev/done-criteria/spec-review.md
git mv claude/skills/feature-dev/done-criteria/phase-03-plan.md claude/skills/feature-dev/done-criteria/plan.md
git mv claude/skills/feature-dev/done-criteria/phase-04-plan-review.md claude/skills/feature-dev/done-criteria/plan-review.md
git mv claude/skills/feature-dev/done-criteria/phase-05-execute.md claude/skills/feature-dev/done-criteria/execute.md
git mv claude/skills/feature-dev/done-criteria/phase-06-accept-test.md claude/skills/feature-dev/done-criteria/accept-test.md
git mv claude/skills/feature-dev/done-criteria/phase-07-doc-audit.md claude/skills/feature-dev/done-criteria/doc-audit.md
git mv claude/skills/feature-dev/done-criteria/phase-08-review.md claude/skills/feature-dev/done-criteria/review.md
git mv claude/skills/feature-dev/done-criteria/phase-09-integrate.md claude/skills/feature-dev/done-criteria/integrate.md
```

- [ ] **Step 3: pipeline.yml のパス参照を更新**

`claude/skills/feature-dev/pipeline.yml` の全 `phase_file` と `done_criteria` を更新:

```yaml
phases:
  - id: design
    phase_file: phases/design.md
    done_criteria: done-criteria/design.md
    skip: false
    produces:
      - spec_file
      - investigation_record

  - id: spec-review
    phase_file: phases/spec-review.md
    done_criteria: done-criteria/spec-review.md
    skip: false
    produces:
      - review_report

  - id: plan
    phase_file: phases/plan.md
    done_criteria: done-criteria/plan.md
    skip: false
    produces:
      - implementation_plan
      - test_cases

  - id: plan-review
    phase_file: phases/plan-review.md
    done_criteria: done-criteria/plan-review.md
    skip: false
    produces:
      - review_report

  - id: execute
    phase_file: phases/execute.md
    done_criteria: done-criteria/execute.md
    skip: false
    produces:
      - code_changes
      - test_results
      - evidence_collection

  - id: accept-test
    phase_file: phases/accept-test.md
    done_criteria: done-criteria/accept-test.md
    skip_unless: --accept
    produces:
      - accept_test_results

  - id: doc-audit
    phase_file: phases/doc-audit.md
    done_criteria: done-criteria/doc-audit.md
    skip_unless: --doc
    produces:
      - doc_audit_report

  - id: review
    phase_file: phases/review.md
    done_criteria: done-criteria/review.md
    skip: false
    produces:
      - review_findings

  - id: integrate
    phase_file: phases/integrate.md
    done_criteria: done-criteria/integrate.md
    skip: false
    handover: never
    produces:
      - merged_branch
      - pr_url
```

- [ ] **Step 4: リネーム結果を検証**

```bash
ls claude/skills/feature-dev/phases/
ls claude/skills/feature-dev/done-criteria/
```

Expected: `phase-` プレフィックスのファイルが 0 件。全ファイルがセマンティック名。

- [ ] **Step 5: コミット**

```bash
git add claude/skills/feature-dev/
git commit -m "rename feature-dev phase files to semantic IDs"
```

---

### Task 2: debug-flow ファイルリネーム + pipeline.yml 更新

**Files:**
- Rename: `claude/skills/debug-flow/phases/phase-*.md` (8 files)
- Rename: `claude/skills/debug-flow/done-criteria/phase-*.md` (8 files)
- Modify: `claude/skills/debug-flow/pipeline.yml`

- [ ] **Step 1: phases/ の 8 ファイルをリネーム**

```bash
cd /Users/nishikataseiichi/.dotfiles
git mv claude/skills/debug-flow/phases/phase-01-rca.md claude/skills/debug-flow/phases/rca.md
git mv claude/skills/debug-flow/phases/phase-02-fix-plan.md claude/skills/debug-flow/phases/fix-plan.md
git mv claude/skills/debug-flow/phases/phase-03-fix-plan-review.md claude/skills/debug-flow/phases/fix-plan-review.md
git mv claude/skills/debug-flow/phases/phase-04-execute.md claude/skills/debug-flow/phases/execute.md
git mv claude/skills/debug-flow/phases/phase-05-accept-test.md claude/skills/debug-flow/phases/accept-test.md
git mv claude/skills/debug-flow/phases/phase-06-doc-audit.md claude/skills/debug-flow/phases/doc-audit.md
git mv claude/skills/debug-flow/phases/phase-07-review.md claude/skills/debug-flow/phases/review.md
git mv claude/skills/debug-flow/phases/phase-08-integrate.md claude/skills/debug-flow/phases/integrate.md
```

- [ ] **Step 2: done-criteria/ の 8 ファイルをリネーム**

```bash
git mv claude/skills/debug-flow/done-criteria/phase-01-rca.md claude/skills/debug-flow/done-criteria/rca.md
git mv claude/skills/debug-flow/done-criteria/phase-02-fix-plan.md claude/skills/debug-flow/done-criteria/fix-plan.md
git mv claude/skills/debug-flow/done-criteria/phase-03-fix-plan-review.md claude/skills/debug-flow/done-criteria/fix-plan-review.md
git mv claude/skills/debug-flow/done-criteria/phase-04-execute.md claude/skills/debug-flow/done-criteria/execute.md
git mv claude/skills/debug-flow/done-criteria/phase-05-accept-test.md claude/skills/debug-flow/done-criteria/accept-test.md
git mv claude/skills/debug-flow/done-criteria/phase-06-doc-audit.md claude/skills/debug-flow/done-criteria/doc-audit.md
git mv claude/skills/debug-flow/done-criteria/phase-07-review.md claude/skills/debug-flow/done-criteria/review.md
git mv claude/skills/debug-flow/done-criteria/phase-08-integrate.md claude/skills/debug-flow/done-criteria/integrate.md
```

- [ ] **Step 3: pipeline.yml のパス参照を更新**

`claude/skills/debug-flow/pipeline.yml` の全 `phase_file` と `done_criteria` を更新:

```yaml
phases:
  - id: rca
    phase_file: phases/rca.md
    done_criteria: done-criteria/rca.md
    skip: false
    produces:
      - rca_report
      - reproduction_test

  - id: fix-plan
    phase_file: phases/fix-plan.md
    done_criteria: done-criteria/fix-plan.md
    skip: false
    produces:
      - fix_plan

  - id: fix-plan-review
    phase_file: phases/fix-plan-review.md
    done_criteria: done-criteria/fix-plan-review.md
    skip: false
    produces:
      - review_report

  - id: execute
    phase_file: phases/execute.md
    done_criteria: done-criteria/execute.md
    skip: false
    produces:
      - code_changes
      - test_results

  - id: accept-test
    phase_file: phases/accept-test.md
    done_criteria: done-criteria/accept-test.md
    skip_unless: --accept
    produces:
      - accept_test_results

  - id: doc-audit
    phase_file: phases/doc-audit.md
    done_criteria: done-criteria/doc-audit.md
    skip_unless: --doc
    produces:
      - doc_audit_report

  - id: review
    phase_file: phases/review.md
    done_criteria: done-criteria/review.md
    skip: false
    produces:
      - review_findings

  - id: integrate
    phase_file: phases/integrate.md
    done_criteria: done-criteria/integrate.md
    skip: false
    handover: never
    produces:
      - merged_branch
      - pr_url
```

- [ ] **Step 4: リネーム結果を検証**

```bash
ls claude/skills/debug-flow/phases/
ls claude/skills/debug-flow/done-criteria/
```

Expected: `phase-` プレフィックスのファイルが 0 件。

- [ ] **Step 5: コミット**

```bash
git add claude/skills/debug-flow/
git commit -m "rename debug-flow phase files to semantic IDs"
```

---

### Task 3: doc-audit done-criteria ファイルリネーム

**Files:**
- Rename: `claude/skills/doc-audit/done-criteria/phase-6-doc-audit.md`

- [ ] **Step 1: リネーム**

```bash
cd /Users/nishikataseiichi/.dotfiles
git mv claude/skills/doc-audit/done-criteria/phase-6-doc-audit.md claude/skills/doc-audit/done-criteria/doc-audit.md
```

- [ ] **Step 2: コミット**

```bash
git add claude/skills/doc-audit/done-criteria/
git commit -m "rename doc-audit done-criteria to semantic ID"
```

---

### Task 4: feature-dev done-criteria 内容更新

全 9 ファイルの frontmatter・criteria ID・アーティファクトパス・prose を更新する。

**Files:**
- Modify: `claude/skills/feature-dev/done-criteria/design.md`
- Modify: `claude/skills/feature-dev/done-criteria/spec-review.md`
- Modify: `claude/skills/feature-dev/done-criteria/plan.md`
- Modify: `claude/skills/feature-dev/done-criteria/plan-review.md`
- Modify: `claude/skills/feature-dev/done-criteria/execute.md`
- Modify: `claude/skills/feature-dev/done-criteria/accept-test.md`
- Modify: `claude/skills/feature-dev/done-criteria/doc-audit.md`
- Modify: `claude/skills/feature-dev/done-criteria/review.md`
- Modify: `claude/skills/feature-dev/done-criteria/integrate.md`

#### 共通変更パターン

全ファイルに適用する変更:

**A. Frontmatter:** `phase: N` 行を削除。`name:` は既にセマンティック ID。

**B. Criteria ID:** プレフィックスを略称に置換（下記マッピング参照）。

**C. Artifact paths:** `phase-N-` プレフィックスを除去。

**D. Prose:** `Phase N` → セマンティック名。

- [ ] **Step 1: design.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/design.md`

Frontmatter:
```
# Before
phase: 1
name: design

# After
name: design
```

Criteria ID: `D1-` → `DSN-` (全件 replace_all)

Prose:
- `Phase 1 Executor` → `当フェーズ Executor`
- `Phase 2 (Spec Review)` → `spec-review`

- [ ] **Step 2: spec-review.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/spec-review.md`

Frontmatter: `phase: 2` 行を削除

Criteria ID: `D2-` → `SPR-` (全件 replace_all)

Artifact paths:
- `artifacts/reviews/phase-2-review.json` → `artifacts/reviews/spec-review.json`

Prose:
- `Phase 3 (Plan)` → `plan`
- `Phase 3 で` → `plan フェーズで`

- [ ] **Step 3: plan.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/plan.md`

Frontmatter: `phase: 3` 行を削除

Criteria ID: `D3-` → `PLN-` (全件 replace_all)

Prose:
- `Phase 3 Executor` → `当フェーズ Executor`
- `Phase 5 でテストコード実装時` → `execute フェーズでテストコード実装時`
- `Phase 5 Executor` → `execute Executor`

- [ ] **Step 4: plan-review.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/plan-review.md`

Frontmatter: `phase: 4` 行を削除

Criteria ID: `D4-` → `PLR-` (全件 replace_all)

Artifact paths:
- `artifacts/reviews/phase-4-review.json` → `artifacts/reviews/plan-review.json`

Prose:
- `Phase 5 Executor` → `execute Executor`

- [ ] **Step 5: execute.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/execute.md`

Frontmatter: `phase: 5` 行を削除

Criteria ID: `D5-` → `EXE-` (全件 replace_all)

Prose:
- `Phase 8 (Code Review)` → `review フェーズ (Code Review)`

- [ ] **Step 6: accept-test.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/accept-test.md`

Frontmatter: `phase: 6` 行を削除（存在する場合）

Criteria ID: `D6-` → `ACT-` (全件 replace_all。ただしこのファイルは新規作成されたため、criteria ID が異なる可能性あり。実ファイルを Read して確認すること)

- [ ] **Step 7: doc-audit.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/doc-audit.md`

Frontmatter: `phase: 7` 行を削除

Criteria ID: `D7-` → `DOC-` (全件 replace_all)

Artifact paths（全件 replace_all）:
- `artifacts/doc-audit/phase-7-script-output.json` → `artifacts/doc-audit/script-output.json`
- `artifacts/doc-audit/phase-7-report.json` → `artifacts/doc-audit/report.json`
- `artifacts/doc-audit/phase-7-doc-check.log` → `artifacts/doc-audit/doc-check.log`
- `artifacts/diff/phase-7-doc.diff` → `artifacts/diff/doc-audit.diff`

Prose:
- `Phase 7 で作成/更新された` → `doc-audit フェーズで作成/更新された`
- `Phase 7 開始タイムスタンプ以降` → `doc-audit フェーズ開始タイムスタンプ以降`
- `Phase 7 開始以降` → `doc-audit フェーズ開始以降`

- [ ] **Step 8: review.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/review.md`

Frontmatter: `phase: 8` 行を削除

Criteria ID:
- `R8-C` → `REV-C` (全件 replace_all)
- `R8-T` → `REV-T` (全件 replace_all)

Artifact paths:
- `artifacts/reviews/phase-8-code-review.json` → `artifacts/reviews/code-review.json`
- `artifacts/reviews/phase-8-test-review.json` → `artifacts/reviews/test-review.json`

- [ ] **Step 9: integrate.md を更新**

ファイル: `claude/skills/feature-dev/done-criteria/integrate.md`

Frontmatter: `phase: 9` 行を削除

Criteria ID: `D9-` → `INT-` (全件 replace_all)

- [ ] **Step 10: 検証 — feature-dev done-criteria に phase 番号参照が残っていないことを確認**

```bash
grep -rn 'phase.\?[0-9]' claude/skills/feature-dev/done-criteria/
```

Expected: 出力なし（0 件）。`forward_check` 内の `Phase N` 参照も含めて全て更新済み。

- [ ] **Step 11: コミット**

```bash
git add claude/skills/feature-dev/done-criteria/
git commit -m "update feature-dev done-criteria to semantic IDs"
```

---

### Task 5: debug-flow done-criteria 内容更新

全 8 ファイルの frontmatter・criteria ID・アーティファクトパス・prose を更新する。

**Files:**
- Modify: `claude/skills/debug-flow/done-criteria/rca.md`
- Modify: `claude/skills/debug-flow/done-criteria/fix-plan.md`
- Modify: `claude/skills/debug-flow/done-criteria/fix-plan-review.md`
- Modify: `claude/skills/debug-flow/done-criteria/execute.md`
- Modify: `claude/skills/debug-flow/done-criteria/accept-test.md`
- Modify: `claude/skills/debug-flow/done-criteria/doc-audit.md`
- Modify: `claude/skills/debug-flow/done-criteria/review.md`
- Modify: `claude/skills/debug-flow/done-criteria/integrate.md`

- [ ] **Step 1: rca.md を更新**

Frontmatter: `phase: 1` 行を削除

Criteria ID: `D1-` → `RCA-` (全件 replace_all)

Prose:
- `Phase 1 Executor` → `当フェーズ Executor`
- `Phase 2 (Fix Plan)` → `fix-plan`

- [ ] **Step 2: fix-plan.md を更新**

Frontmatter: `phase: 2` 行を削除

Criteria ID: `D2-` → `FPL-` (全件 replace_all)

- [ ] **Step 3: fix-plan-review.md を更新**

Frontmatter: `phase: 3` 行を削除

Criteria ID: `D3-` → `FPR-` (全件 replace_all)

Artifact paths:
- `artifacts/reviews/phase-3-review.json` → `artifacts/reviews/fix-plan-review.json`

- [ ] **Step 4: execute.md を更新**

Frontmatter: `phase: 4` 行を削除

Criteria ID: `D4-` → `EXE-` (全件 replace_all)

Prose:
- `Phase 7 (Code Review)` → `review フェーズ (Code Review)`

- [ ] **Step 5: accept-test.md を更新**

Frontmatter: `phase: 5` 行を削除（存在する場合）

Criteria ID: 実ファイルを Read して確認。`D5-` → `ACT-` (全件 replace_all)

- [ ] **Step 6: doc-audit.md を更新**

Frontmatter: `phase: 6` 行を削除

Criteria ID: `D6-` → `DOC-` (全件 replace_all)

Artifact paths（全件 replace_all）:
- `artifacts/doc-audit/phase-6-script-output.json` → `artifacts/doc-audit/script-output.json`
- `artifacts/doc-audit/phase-6-report.json` → `artifacts/doc-audit/report.json`
- `artifacts/doc-audit/phase-6-doc-check.log` → `artifacts/doc-audit/doc-check.log`
- `artifacts/diff/phase-6-doc.diff` → `artifacts/diff/doc-audit.diff`

Prose:
- `Phase 6 で作成/更新された` → `doc-audit フェーズで作成/更新された`
- `Phase 6 開始タイムスタンプ以降` → `doc-audit フェーズ開始タイムスタンプ以降`
- `Phase 6 開始以降` → `doc-audit フェーズ開始以降`

- [ ] **Step 7: review.md を更新**

Frontmatter: `phase: 7` 行を削除

Criteria ID:
- `R7-C` → `REV-C` (全件 replace_all)
- `R7-T` → `REV-T` (全件 replace_all)

Artifact paths:
- `artifacts/reviews/phase-7-code-review.json` → `artifacts/reviews/code-review.json`
- `artifacts/reviews/phase-7-test-review.json` → `artifacts/reviews/test-review.json`

- [ ] **Step 8: integrate.md を更新**

Frontmatter: `phase: 8` 行を削除

Criteria ID: `D8-` → `INT-` (全件 replace_all)

- [ ] **Step 9: 検証 — debug-flow done-criteria に phase 番号参照が残っていないことを確認**

```bash
grep -rn 'phase.\?[0-9]' claude/skills/debug-flow/done-criteria/
```

Expected: 出力なし。

- [ ] **Step 10: コミット**

```bash
git add claude/skills/debug-flow/done-criteria/
git commit -m "update debug-flow done-criteria to semantic IDs"
```

---

### Task 6: doc-audit done-criteria 内容更新

**Files:**
- Modify: `claude/skills/doc-audit/done-criteria/doc-audit.md`

- [ ] **Step 1: frontmatter と criteria ID を更新**

Frontmatter: `phase: 6` 行を削除

Criteria ID: `D6-` → `DOC-` (全件 replace_all)

Artifact paths（全件 replace_all）:
- `artifacts/doc-audit/phase-6-script-output.json` → `artifacts/doc-audit/script-output.json`
- `artifacts/doc-audit/phase-6-report.json` → `artifacts/doc-audit/report.json`
- `artifacts/doc-audit/phase-6-doc-check.log` → `artifacts/doc-audit/doc-check.log`
- `artifacts/diff/phase-6-doc.diff` → `artifacts/diff/doc-audit.diff`

Prose:
- `Phase 6 で作成/更新された` → `doc-audit フェーズで作成/更新された`
- `Phase 6 開始タイムスタンプ以降` → `doc-audit フェーズ開始タイムスタンプ以降`
- `Phase 6 開始以降` → `doc-audit フェーズ開始以降`

- [ ] **Step 2: 検証**

```bash
grep -n 'phase.\?[0-9]' claude/skills/doc-audit/done-criteria/doc-audit.md
```

Expected: 出力なし。

- [ ] **Step 3: コミット**

```bash
git add claude/skills/doc-audit/done-criteria/
git commit -m "update doc-audit done-criteria to semantic IDs"
```

---

### Task 7: feature-dev / debug-flow SKILL.md 更新

**Files:**
- Modify: `claude/skills/feature-dev/SKILL.md`
- Modify: `claude/skills/debug-flow/SKILL.md`

- [ ] **Step 1: feature-dev/SKILL.md を更新**

2箇所を編集:

Edit 1 — New Mode セクション (line 47):
```
# Before
2. Phase 1 (design) から開始

# After
2. 最初のフェーズ (design) から開始
```

Edit 2 — フェーズディスパッチ (line 55):
```
# Before
3. `phases/phase-XX-*.md` を Read（遅延ロード）

# After
3. `phase_file` で指定されたファイルを Read（遅延ロード）
```

- [ ] **Step 2: debug-flow/SKILL.md を更新**

2箇所を編集:

Edit 1 — New Mode セクション (line 46):
```
# Before
2. Phase 1 (rca) から開始

# After
2. 最初のフェーズ (rca) から開始
```

Edit 2 — フェーズディスパッチ (line 55):
```
# Before
3. `phases/phase-XX-*.md` を Read（遅延ロード）

# After
3. `phase_file` で指定されたファイルを Read（遅延ロード）
```

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/SKILL.md claude/skills/debug-flow/SKILL.md
git commit -m "update SKILL.md phase dispatch to use pipeline.yml paths"
```

---

### Task 8: feature-dev phases/ と references/ 内容更新

phases/ および references/ ファイル内で `Phase N` をハードコードしている箇所を更新する。

**Files:**
- Modify: `claude/skills/feature-dev/phases/design.md`
- Modify: `claude/skills/feature-dev/phases/execute.md`
- Modify: `claude/skills/feature-dev/references/brainstorming-supplement.md`

- [ ] **Step 1: design.md — Phase 1 参照を更新**

ファイル: `claude/skills/feature-dev/phases/design.md`

```
# Before
Phase 1 開始前に:

# After
design フェーズ開始前に:
```

- [ ] **Step 2: execute.md — Phase 1 参照を更新**

ファイル: `claude/skills/feature-dev/phases/execute.md`

```
# Before
Phase 1 Audit Gate 完了後に生成された Evidence Plan に基づき:

# After
design Audit Gate 完了後に生成された Evidence Plan に基づき:
```

- [ ] **Step 3: brainstorming-supplement.md — Phase N 参照を更新**

ファイル: `claude/skills/feature-dev/references/brainstorming-supplement.md`

5箇所を編集:

```
# Before
  feature-dev Phase 1 専用。
# After
  feature-dev design フェーズ専用。

# Before
後続フェーズ（Phase 4 の implementation-review-consistency、{review} の code-review-impact）で参照される
# After
後続フェーズ（plan-review の implementation-review-consistency、review の code-review-impact）で参照される

# Before
**品質基準（Phase 3 の Given/When/Then 展開時に適用）:**
# After
**品質基準（plan の Given/When/Then 展開時に適用）:**

# Before
この基準を満たさないテストケースは Phase 4 の implementation-review-feasibility で REJECT される。
# After
この基準を満たさないテストケースは plan-review の implementation-review-feasibility で REJECT される。

# Before
※ Given/When/Then レベルの詳細化は Phase 3（Plan）で行う。設計書内のテスト観点は Phase 3 で `docs/plans/*-test-cases.md` に展開される。
# After
※ Given/When/Then レベルの詳細化は plan フェーズで行う。設計書内のテスト観点は plan フェーズで `docs/plans/*-test-cases.md` に展開される。
```

- [ ] **Step 4: 他の phases/ と references/ ファイルを確認**

```bash
grep -rn 'Phase [0-9]' claude/skills/feature-dev/phases/ claude/skills/feature-dev/references/ claude/skills/debug-flow/phases/ claude/skills/debug-flow/references/
```

Expected: 追加の要修正箇所がないことを確認。あれば同様に更新。

- [ ] **Step 5: コミット**

```bash
git add claude/skills/feature-dev/phases/ claude/skills/feature-dev/references/ claude/skills/debug-flow/phases/ claude/skills/debug-flow/references/
git commit -m "update phase and reference prose to semantic IDs"
```

---

### Task 9: handover/SKILL.md 更新

**Files:**
- Modify: `claude/skills/handover/SKILL.md`

- [ ] **Step 1: project-state.json スキーマ例の phase_summaries を更新**

Line 98-100 付近 — phase_observations:
```
# Before
      "phase": 5,
      "phase_name": "execute",

# After
      "phase": "execute",
```

`"phase_name"` フィールドは `"phase"` がセマンティック ID になるため冗長。削除する。

- [ ] **Step 2: session_notes の relates_to_phase を更新**

Line 118 付近:
```
# Before
      "relates_to_phase": 5

# After
      "relates_to_phase": "execute"
```

- [ ] **Step 3: criteria_id 例を更新**

Line 105 付近:
```
# Before
          "criteria_id": "D5-08",

# After
          "criteria_id": "EXE-08",
```

- [ ] **Step 4: linear セクションの last_synced_phase を更新**

Line 124 付近:
```
# Before
    "last_synced_phase": 5,

# After
    "last_synced_phase": "execute",
```

- [ ] **Step 5: phase_summaries のキーと値を更新**

Line 127-129:
```
# Before
  "phase_summaries": {
    "1": "phase-summaries/phase-01-design.yml",
    "2": "phase-summaries/phase-02-spec-review.yml"
  },

# After
  "phase_summaries": {
    "design": "phase-summaries/design.yml",
    "spec-review": "phase-summaries/spec-review.yml"
  },
```

- [ ] **Step 6: Observations / Session Notes テンプレートの Phase N を更新**

Line 236 付近:
```
# Before
## Observations (from Audit)
- [Phase N] criteria_id: observation（recommendation）

## Session Notes
- [category] content（Phase N）

# After
## Observations (from Audit)
- [<phase_id>] criteria_id: observation（recommendation）

## Session Notes
- [category] content（<phase_id>）
```

- [ ] **Step 7: Phase Progress テンプレートを更新**

Line 241-247:
```
# Before
## Phase Progress（pipeline ワークフロー時のみ）
- [Phase 1] Design ✅ (spec: <path>)
- [Phase 2] Spec Review ✅ (findings: 0 blocker)
- [Phase 3] Plan ✅ (plan: <path>)
- [Phase 5] Execute ✅
  - Concerns: <concerns for later phases>
→ Current Phase: N (<phase_name>)

# After
## Phase Progress（pipeline ワークフロー時のみ）
- [design] ✅ (spec: <path>)
- [spec-review] ✅ (findings: 0 blocker)
- [plan] ✅ (plan: <path>)
- [execute] ✅
  - Concerns: <concerns for later phases>
→ Current Phase: <phase_id>
```

- [ ] **Step 8: phase_observations マージルールの phase 参照を確認**

Line 148 付近:
```
# Before
   - phase_observations: 同一 phase のエントリは上書き

# After（変更なし — "phase" はフィールド名なので OK。値がセマンティック ID になる）
```

- [ ] **Step 9: コミット**

```bash
git add claude/skills/handover/SKILL.md
git commit -m "update handover schema to semantic phase IDs"
```

---

### Task 10: continue/SKILL.md 更新

**Files:**
- Modify: `claude/skills/continue/SKILL.md`

- [ ] **Step 1: セッション一覧表示の Phase 参照を更新**

Line 31 付近:
```
# Before
  [1] master/20260330-120000 — 残2件 / 完3件 — 次: Phase 5 実装

# After
  [1] master/20260330-120000 — 残2件 / 完3件 — 次: execute 実装
```

- [ ] **Step 2: current_phase 判定ロジックを更新**

Line 60 付近:
```
# Before
   3. `current_phase` を判定する（`phase_summaries` に存在する最大フェーズ番号 + 1）

# After
   3. `current_phase` を判定する（`pipeline.yml` のフェーズ配列順で、`phase_summaries` に存在しない最初のフェーズ）
```

- [ ] **Step 3: 表示フォーマットを更新**

Line 73-83 付近:
```
# Before
   Phase Progress:
     Phase 1 (design) ✅
     Phase 2 (spec-review) ✅
     Phase 3 (plan) ✅
     → Current: Phase 4 (plan-review)

   Concerns for current phase:
     - <concerns with target_phase matching current phase>

   Pipeline: {pipeline} のセッションを検出しました。
   Phase {N} ({phase_name}) から Resume Mode で起動します。

# After
   Phase Progress:
     design ✅
     spec-review ✅
     plan ✅
     → Current: plan-review

   Concerns for current phase:
     - <concerns with target_phase matching current phase>

   Pipeline: {pipeline} のセッションを検出しました。
   {phase_id} から Resume Mode で起動します。
```

- [ ] **Step 4: コミット**

```bash
git add claude/skills/continue/SKILL.md
git commit -m "update continue skill to semantic phase IDs"
```

---

### Task 11: linear-sync テンプレート更新

**Files:**
- Modify: `claude/skills/linear-sync/templates/document.md`

- [ ] **Step 1: Phase Progress テーブルを更新**

Line 30-34 付近:
```
# Before
| # | Phase | Status | Summary | Evidence |
|---|-------|--------|---------|----------|
| 1 | {phase_1_name} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| 2 | {phase_2_name} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| ... | ... | ... | ... | ... |

# After
| Phase | Status | Summary | Evidence |
|-------|--------|---------|----------|
| {phase_id} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| ... | ... | ... | ... |
```

`#` 列を削除。`phase_N_name` テンプレート変数を `phase_id`（pipeline.yml の id）に置換。

- [ ] **Step 2: Overview の Current Phase を更新**

Line 26 付近:
```
# Before
| Current Phase | {current_phase_number} / {total_phases} ({current_phase_name}) |

# After
| Current Phase | {current_phase_id} ({completed_count} / {total_phases}) |
```

- [ ] **Step 3: Evidence Index の Phase 列を更新**

Line 38-39 付近:
```
# Before
| Phase | File | Description |
|-------|------|-------------|
| {phase_number} | {filename} | {label / description} |

# After
| Phase | File | Description |
|-------|------|-------------|
| {phase_id} | {filename} | {label / description} |
```

- [ ] **Step 4: フェーズ一覧を更新**

Line 57-80 — 「pipeline ごとのフェーズ一覧」セクション:

```markdown
### debug-flow (8 phases)
1. rca
2. fix-plan
3. fix-plan-review
4. execute
5. accept-test
6. doc-audit
7. review
8. integrate

### feature-dev (9 phases)
1. design
2. spec-review
3. plan
4. plan-review
5. execute
6. accept-test
7. doc-audit
8. review
9. integrate
```

注: ここの番号リストはパイプライン内の順序を示す参考情報であり、ID ではないため番号付きリストのままで問題ない。フェーズ名をセマンティック ID に統一する。

- [ ] **Step 5: コミット**

```bash
git add claude/skills/linear-sync/templates/document.md
git commit -m "update linear-sync template to semantic phase IDs"
```

---

### Task 12: 最終検証

**Files:** None (read-only verification)

- [ ] **Step 1: feature-dev / debug-flow / doc-audit 配下で残存する phase 番号参照を検索**

```bash
grep -rn 'phase-[0-9]' claude/skills/feature-dev/ claude/skills/debug-flow/ claude/skills/doc-audit/
```

Expected: 出力なし（0 件）。

- [ ] **Step 2: `Phase [0-9]` パターンで残存する prose を検索**

```bash
grep -rn 'Phase [0-9]' claude/skills/feature-dev/ claude/skills/debug-flow/ claude/skills/doc-audit/ claude/skills/handover/ claude/skills/continue/ claude/skills/linear-sync/
```

Expected: 出力なし。

- [ ] **Step 3: pipeline.yml のパスが全て実在することを検証**

```bash
cd /Users/nishikataseiichi/.dotfiles
for f in $(grep 'phase_file:\|done_criteria:' claude/skills/feature-dev/pipeline.yml claude/skills/debug-flow/pipeline.yml | sed 's/.*: //'); do
  dir=$(echo "$f" | grep -o 'feature-dev\|debug-flow' || true)
  if [ -z "$dir" ]; then continue; fi
  # pipeline.yml からの相対パス
done

# より簡潔に: 各 pipeline.yml の参照ファイルが存在することを確認
python3 -c "
import yaml, os, sys
for pipeline in ['claude/skills/feature-dev/pipeline.yml', 'claude/skills/debug-flow/pipeline.yml']:
    base = os.path.dirname(pipeline)
    with open(pipeline) as f:
        data = yaml.safe_load(f)
    for phase in data['phases']:
        for key in ['phase_file', 'done_criteria']:
            path = os.path.join(base, phase[key])
            if not os.path.exists(path):
                print(f'MISSING: {path}')
                sys.exit(1)
    print(f'OK: {pipeline} — all {len(data[\"phases\"])} phases resolved')
"
```

Expected:
```
OK: claude/skills/feature-dev/pipeline.yml — all 9 phases resolved
OK: claude/skills/debug-flow/pipeline.yml — all 8 phases resolved
```

- [ ] **Step 4: done-criteria frontmatter に `phase: [数字]` が残っていないことを確認**

```bash
grep -rn '^phase: [0-9]' claude/skills/feature-dev/done-criteria/ claude/skills/debug-flow/done-criteria/ claude/skills/doc-audit/done-criteria/
```

Expected: 出力なし。

- [ ] **Step 5: handover / continue の番号参照を最終確認**

```bash
grep -n 'phase-[0-9]\|"[0-9]":.*phase-summaries\|Phase [0-9]' claude/skills/handover/SKILL.md claude/skills/continue/SKILL.md
```

Expected: 出力なし。
