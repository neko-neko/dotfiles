# Artifact Contract Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** workflow-engine の artifact lifecycle を一元化し、Verification/Validation を構造的に分離する

**Architecture:** pipeline.yml に artifacts セクションを導入し、成果物の型・保存先パターン・contract（verification/validation）を一元定義する。done-criteria は operations（フェーズ固有）+ artifact_validation.additional（contract 追加）に再構成。Phase Summary に inner_loop_state と validation_record を追加。resume.md を 4-Phase プロトコルに全面改定。

**Tech Stack:** YAML (pipeline定義), Markdown (phase/module/done-criteria), JSON Schema (pipeline validation)

---

### Task 1: pipeline.schema.json の作成

**Files:**
- Create: `claude/skills/workflow-engine/schema/pipeline.schema.json`
- Delete: `claude/skills/workflow-engine/schema/pipeline.v2.schema.json`

- [ ] **Step 1: 旧スキーマの削除**

```bash
rm claude/skills/workflow-engine/schema/pipeline.v2.schema.json
```

- [ ] **Step 2: 新スキーマファイルの作成**

`claude/skills/workflow-engine/schema/pipeline.schema.json` に以下を作成:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "pipeline.schema.json",
  "title": "Workflow Engine Pipeline Definition",
  "description": "workflow-engine が駆動するパイプラインの定義スキーマ。artifacts セクションで成果物のライフサイクルを一元管理し、contract で Verification/Validation を型レベルで分離する。",
  "type": "object",
  "required": ["pipeline", "version", "modules", "artifacts", "phases", "settings"],
  "additionalProperties": false,

  "properties": {
    "pipeline": {
      "type": "string",
      "description": "パイプラインの識別子。",
      "pattern": "^[a-z][a-z0-9-]*$"
    },

    "version": {
      "type": "integer",
      "const": 3
    },

    "modules": {
      "type": "array",
      "items": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
      "minItems": 1,
      "uniqueItems": true
    },

    "artifacts": {
      "type": "object",
      "description": "成果物の型定義。各 artifact は produced_by/consumed_by で依存関係を宣言し、contract で検証基準を定義する。",
      "additionalProperties": { "$ref": "#/$defs/Artifact" },
      "minProperties": 1
    },

    "phases": {
      "type": "array",
      "items": { "$ref": "#/$defs/Phase" },
      "minItems": 1
    },

    "integrations": {
      "type": "array",
      "items": { "$ref": "#/$defs/Integration" }
    },

    "regate": { "$ref": "#/$defs/Regate" },

    "settings": { "$ref": "#/$defs/Settings" }
  },

  "allOf": [
    {
      "if": { "properties": { "modules": { "contains": { "const": "regate" } } } },
      "then": { "required": ["regate"] }
    }
  ],

  "$defs": {

    "Artifact": {
      "type": "object",
      "description": "1つの成果物の型定義。",
      "required": ["type", "produced_by", "consumed_by", "contract"],
      "additionalProperties": false,
      "properties": {
        "type": {
          "type": "string",
          "enum": ["file", "git_range", "inline"],
          "description": "file: ファイルシステム上の成果物。git_range: git コミット範囲。inline: Phase Summary 内の短い値。"
        },
        "pattern": {
          "type": "string",
          "description": "type: file の場合のファイルパスパターン。{date} はランタイムで YYYY-MM-DD に展開される。"
        },
        "produced_by": {
          "type": "string",
          "description": "この artifact を生成するフェーズの ID。phases 配列内に存在する必要がある。"
        },
        "consumed_by": {
          "type": "array",
          "items": { "type": "string" },
          "description": "この artifact を消費するフェーズ ID のリスト。engine が Phase Summary チェーンから自動解決する。"
        },
        "contract": { "$ref": "#/$defs/Contract" }
      }
    },

    "Contract": {
      "type": "object",
      "description": "成果物の検証契約。verification は将来 CLI に移行する機械的チェック、validation は LLM が担当する意味的チェック。",
      "required": ["verification", "validation"],
      "additionalProperties": false,
      "properties": {
        "verification": {
          "type": "array",
          "items": { "$ref": "#/$defs/VerificationCheck" }
        },
        "validation": {
          "type": "array",
          "items": { "$ref": "#/$defs/ValidationCheck" }
        }
      }
    },

    "VerificationCheck": {
      "type": "object",
      "required": ["check"],
      "additionalProperties": true,
      "properties": {
        "check": {
          "type": "string",
          "enum": ["file_exists", "git_committed", "sections_present", "build_passes", "tests_pass", "lint_clean", "no_failures", "no_conflicts", "no_uncommitted_changes", "test_fails"],
          "description": "機械的に実行可能な検証タイプ。"
        },
        "target": { "type": "string" },
        "sections": { "type": "array", "items": { "type": "string" } }
      }
    },

    "ValidationCheck": {
      "type": "object",
      "required": ["question", "against"],
      "additionalProperties": false,
      "properties": {
        "question": {
          "type": "string",
          "description": "LLM が判断する意味的な検証質問。"
        },
        "against": {
          "oneOf": [
            { "type": "string" },
            { "type": "array", "items": { "type": "string" } }
          ],
          "description": "検証対象。artifact 名、user_request、codebase のいずれか。"
        }
      }
    },

    "Phase": {
      "type": "object",
      "required": ["id", "phase_file"],
      "additionalProperties": false,
      "properties": {
        "id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
        "phase_file": { "type": "string" },
        "skip": { "type": "boolean", "default": false },
        "skip_unless": { "type": "string", "pattern": "^--[a-z][a-z0-9-]*$" },
        "uses": {
          "type": "array",
          "items": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
          "uniqueItems": true
        },
        "handover": { "type": "string", "enum": ["always", "optional", "never"] }
      },
      "not": { "required": ["skip", "skip_unless"] }
    },

    "Integration": {
      "type": "object",
      "required": ["skill", "enabled_by", "hooks"],
      "additionalProperties": false,
      "properties": {
        "skill": { "type": "string" },
        "enabled_by": { "type": "string", "pattern": "^--[a-z][a-z0-9-]*$" },
        "hooks": {
          "type": "object",
          "propertyNames": {
            "enum": ["on_pipeline_start", "on_phase_start", "on_phase_complete", "on_audit_fail", "on_regate", "on_handover", "on_pipeline_complete"]
          },
          "additionalProperties": { "type": "array", "items": { "type": "string" }, "minItems": 1 },
          "minProperties": 1
        }
      }
    },

    "Regate": {
      "type": "object",
      "required": ["verification_chain"],
      "properties": {
        "verification_chain": { "type": "array", "items": { "type": "string" }, "minItems": 1 }
      },
      "additionalProperties": { "$ref": "#/$defs/RegateStrategy" }
    },

    "RegateStrategy": {
      "type": "object",
      "required": ["strategy_file", "rewind_to"],
      "additionalProperties": false,
      "properties": {
        "strategy_file": { "type": "string" },
        "rewind_to": { "type": "string" },
        "max_retries": { "type": "integer", "minimum": 1 }
      }
    },

    "Settings": {
      "type": "object",
      "required": ["default_handover", "max_phase_retries", "context_budget"],
      "additionalProperties": false,
      "properties": {
        "default_handover": { "type": "string", "enum": ["always", "optional", "never"] },
        "max_phase_retries": { "type": "integer", "minimum": 1 },
        "context_budget": { "$ref": "#/$defs/ContextBudget" }
      }
    },

    "ContextBudget": {
      "type": "object",
      "required": ["orchestrator", "phase", "references"],
      "additionalProperties": false,
      "properties": {
        "orchestrator": { "type": "integer", "minimum": 1 },
        "phase": { "type": "integer", "minimum": 1 },
        "references": { "type": "integer", "minimum": 1 }
      }
    }
  }
}
```

- [ ] **Step 3: スキーマの静的検証**

```bash
# JSON として valid であることを確認
python3 -c "import json; json.load(open('claude/skills/workflow-engine/schema/pipeline.schema.json'))" && echo "Valid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 4: コミット**

```bash
git add claude/skills/workflow-engine/schema/pipeline.schema.json
git rm claude/skills/workflow-engine/schema/pipeline.v2.schema.json
git commit -m "replace pipeline.v2.schema with artifact-contract-aware pipeline.schema"
```

---

### Task 2: feature-dev/pipeline.yml を v3 に書き換え

**Files:**
- Modify: `claude/skills/feature-dev/pipeline.yml`

- [ ] **Step 1: pipeline.yml を完全書き換え**

`claude/skills/feature-dev/pipeline.yml` の内容を以下に置換:

```yaml
# yaml-language-server: $schema=../../workflow-engine/schema/pipeline.schema.json
pipeline: feature-dev
version: 3

modules:
  - audit
  - autonomy
  - regate
  - resume
  - phase-summary
  - context-budget

artifacts:
  spec_file:
    type: file
    pattern: "docs/superpowers/specs/{date}-*-design.md"
    produced_by: design
    consumed_by: [spec-review, plan, plan-review]
    contract:
      verification:
        - { check: file_exists, target: "{pattern}" }
        - { check: git_committed, target: "{pattern}" }
        - { check: sections_present, sections: [requirements, components, impact-analysis, test-perspectives] }
      validation:
        - { question: "ユーザーの要求を全て要件として捕捉しているか", against: user_request }
        - { question: "Impact Analysis が実コードベースと整合しているか", against: codebase }
        - { question: "テスト観点がユーザーの成功基準をカバーしているか", against: user_request }

  investigation_record:
    type: file
    produced_by: design
    consumed_by: []
    contract:
      verification:
        - { check: file_exists }
      validation: []

  spec_review_report:
    type: inline
    produced_by: spec-review
    consumed_by: []
    contract:
      verification: []
      validation: []

  implementation_plan:
    type: file
    pattern: "docs/superpowers/plans/{date}-*-plan.md"
    produced_by: plan
    consumed_by: [plan-review, execute]
    contract:
      verification:
        - { check: file_exists, target: "{pattern}" }
        - { check: git_committed, target: "{pattern}" }
      validation:
        - { question: "全設計要件がタスクに分解されているか", against: spec_file }
        - { question: "タスク依存関係が実装順序として妥当か", against: codebase }

  test_cases:
    type: file
    produced_by: plan
    consumed_by: [plan-review, execute]
    contract:
      verification:
        - { check: file_exists }
      validation:
        - { question: "テストケースが Given/When/Then で具体化されているか", against: spec_file }

  plan_review_report:
    type: inline
    produced_by: plan-review
    consumed_by: []
    contract:
      verification: []
      validation: []

  code_changes:
    type: git_range
    produced_by: execute
    consumed_by: [accept-test, doc-audit, review, integrate]
    contract:
      verification:
        - { check: build_passes }
        - { check: tests_pass }
        - { check: lint_clean }
      validation:
        - { question: "設計→計画→実装の変換が意味的に正しいか", against: [spec_file, implementation_plan] }
        - { question: "新規テストが要件の意図を検証しているか（非トートロジー）", against: spec_file }

  test_results:
    type: inline
    produced_by: execute
    consumed_by: [review]
    contract:
      verification:
        - { check: no_failures }
      validation: []

  evidence_collection:
    type: file
    produced_by: execute
    consumed_by: [review]
    contract:
      verification:
        - { check: file_exists }
      validation: []

  accept_test_results:
    type: file
    produced_by: accept-test
    consumed_by: []
    contract:
      verification:
        - { check: file_exists }
      validation:
        - { question: "テストシナリオがプロジェクト特性と主要ユーザーフローを網羅しているか", against: spec_file }

  doc_audit_report:
    type: file
    produced_by: doc-audit
    consumed_by: []
    contract:
      verification:
        - { check: file_exists }
      validation: []

  review_findings:
    type: inline
    produced_by: review
    consumed_by: []
    contract:
      verification: []
      validation:
        - { question: "ユーザー承認済み findings が全て適用されているか", against: code_changes }

  merged_branch:
    type: inline
    produced_by: integrate
    consumed_by: []
    contract:
      verification:
        - { check: no_conflicts }
        - { check: no_uncommitted_changes }
      validation: []

  pr_url:
    type: inline
    produced_by: integrate
    consumed_by: []
    contract:
      verification: []
      validation: []

integrations:
  - skill: linear-sync
    enabled_by: --linear
    hooks:
      on_pipeline_start: [sync_workflow_start]
      on_phase_complete: [sync_phase_summary, sync_evidence]
      on_regate: [sync_regate]
      on_handover: [sync_session]
      on_pipeline_complete: [sync_complete]

phases:
  - id: design
    phase_file: phases/design.md

  - id: spec-review
    phase_file: phases/spec-review.md

  - id: plan
    phase_file: phases/plan.md

  - id: plan-review
    phase_file: phases/plan-review.md

  - id: execute
    phase_file: phases/execute.md
    uses: [inner-loop]

  - id: accept-test
    phase_file: phases/accept-test.md
    skip_unless: --accept

  - id: doc-audit
    phase_file: phases/doc-audit.md
    skip_unless: --doc

  - id: review
    phase_file: phases/review.md

  - id: integrate
    phase_file: phases/integrate.md
    handover: never

regate:
  verification_chain: [execute, accept-test, review]

  review_findings:
    strategy_file: regate/review-findings.md
    rewind_to: execute

  test_failure:
    strategy_file: regate/test-failure.md
    rewind_to: execute

  audit_failure:
    strategy_file: regate/audit-failure.md
    rewind_to: current
    max_retries: 3

settings:
  default_handover: always
  max_phase_retries: 3
  context_budget:
    orchestrator: 150
    phase: 100
    references: 200
```

- [ ] **Step 2: YAML 構文検証**

```bash
python3 -c "import yaml; yaml.safe_load(open('claude/skills/feature-dev/pipeline.yml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

- [ ] **Step 3: artifact chain の整合性確認**

```bash
# produced_by の全 ID が phases に存在するか確認
python3 -c "
import yaml
p = yaml.safe_load(open('claude/skills/feature-dev/pipeline.yml'))
phase_ids = {ph['id'] for ph in p['phases']}
for name, art in p['artifacts'].items():
    assert art['produced_by'] in phase_ids, f'{name}.produced_by={art[\"produced_by\"]} not in phases'
    for c in art['consumed_by']:
        assert c in phase_ids, f'{name}.consumed_by={c} not in phases'
print('All artifact references valid')
"
```

Expected: `All artifact references valid`

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/pipeline.yml
git commit -m "rewrite feature-dev pipeline.yml to v3 with artifact contracts"
```

---

### Task 3: debug-flow/pipeline.yml を v3 に書き換え

**Files:**
- Modify: `claude/skills/debug-flow/pipeline.yml`

- [ ] **Step 1: pipeline.yml を完全書き換え**

`claude/skills/debug-flow/pipeline.yml` の内容を以下に置換:

```yaml
# yaml-language-server: $schema=../../workflow-engine/schema/pipeline.schema.json
pipeline: debug-flow
version: 3

modules:
  - audit
  - autonomy
  - regate
  - resume
  - phase-summary
  - context-budget

artifacts:
  rca_report:
    type: file
    pattern: "docs/debug/{date}-*-rca.md"
    produced_by: rca
    consumed_by: [fix-plan, fix-plan-review]
    contract:
      verification:
        - { check: file_exists, target: "{pattern}" }
        - { check: git_committed, target: "{pattern}" }
        - { check: sections_present, sections: [symptoms, investigation, root-cause, fix-strategy] }
      validation:
        - { question: "根本原因がコードベースの実態と整合しているか", against: codebase }
        - { question: "Fix Strategy が根本原因を解決するアプローチか", against: codebase }

  reproduction_test:
    type: file
    produced_by: rca
    consumed_by: [execute]
    contract:
      verification:
        - { check: test_fails }
        - { check: git_committed }
      validation:
        - { question: "テストが根本原因のメカニズムを正確に再現しているか", against: rca_report }

  fix_plan:
    type: file
    pattern: "docs/plans/{date}-*-fix-plan.md"
    produced_by: fix-plan
    consumed_by: [fix-plan-review, execute]
    contract:
      verification:
        - { check: file_exists, target: "{pattern}" }
        - { check: git_committed, target: "{pattern}" }
      validation:
        - { question: "Fix Strategy の全項目がタスクに分解されているか", against: rca_report }
        - { question: "タスク依存関係が実装順序として妥当か", against: codebase }

  test_cases:
    type: file
    produced_by: fix-plan
    consumed_by: [fix-plan-review, execute]
    contract:
      verification:
        - { check: file_exists }
      validation:
        - { question: "テストケースが Given/When/Then で具体化されているか", against: rca_report }

  fix_plan_review_report:
    type: inline
    produced_by: fix-plan-review
    consumed_by: []
    contract:
      verification: []
      validation: []

  code_changes:
    type: git_range
    produced_by: execute
    consumed_by: [accept-test, doc-audit, review, integrate]
    contract:
      verification:
        - { check: build_passes }
        - { check: tests_pass }
        - { check: lint_clean }
      validation:
        - { question: "修正が根本原因を正しく解決しているか", against: [rca_report, fix_plan] }
        - { question: "新規テストが根本原因のメカニズムを検証しているか（非トートロジー）", against: rca_report }

  test_results:
    type: inline
    produced_by: execute
    consumed_by: [review]
    contract:
      verification:
        - { check: no_failures }
      validation: []

  accept_test_results:
    type: file
    produced_by: accept-test
    consumed_by: []
    contract:
      verification:
        - { check: file_exists }
      validation:
        - { question: "テストシナリオが修正対象の障害シナリオをカバーしているか", against: rca_report }

  doc_audit_report:
    type: file
    produced_by: doc-audit
    consumed_by: []
    contract:
      verification:
        - { check: file_exists }
      validation: []

  review_findings:
    type: inline
    produced_by: review
    consumed_by: []
    contract:
      verification: []
      validation:
        - { question: "ユーザー承認済み findings が全て適用されているか", against: code_changes }

  merged_branch:
    type: inline
    produced_by: integrate
    consumed_by: []
    contract:
      verification:
        - { check: no_conflicts }
        - { check: no_uncommitted_changes }
      validation: []

  pr_url:
    type: inline
    produced_by: integrate
    consumed_by: []
    contract:
      verification: []
      validation: []

integrations:
  - skill: linear-sync
    enabled_by: --linear
    hooks:
      on_pipeline_start: [sync_workflow_start]
      on_phase_complete: [sync_phase_summary, sync_evidence]
      on_regate: [sync_regate]
      on_handover: [sync_session]
      on_pipeline_complete: [sync_complete]

phases:
  - id: rca
    phase_file: phases/rca.md

  - id: fix-plan
    phase_file: phases/fix-plan.md

  - id: fix-plan-review
    phase_file: phases/fix-plan-review.md

  - id: execute
    phase_file: phases/execute.md
    uses: [inner-loop]

  - id: accept-test
    phase_file: phases/accept-test.md
    skip_unless: --accept

  - id: doc-audit
    phase_file: phases/doc-audit.md
    skip_unless: --doc

  - id: review
    phase_file: phases/review.md

  - id: integrate
    phase_file: phases/integrate.md
    handover: never

regate:
  verification_chain: [execute, accept-test, review]

  review_findings:
    strategy_file: regate/review-findings.md
    rewind_to: execute

  test_failure:
    strategy_file: regate/test-failure.md
    rewind_to: execute

  audit_failure:
    strategy_file: regate/audit-failure.md
    rewind_to: current
    max_retries: 3

settings:
  default_handover: always
  max_phase_retries: 3
  context_budget:
    orchestrator: 150
    phase: 100
    references: 200
```

- [ ] **Step 2: YAML 構文検証 + artifact chain 整合性確認**

```bash
python3 -c "
import yaml
p = yaml.safe_load(open('claude/skills/debug-flow/pipeline.yml'))
phase_ids = {ph['id'] for ph in p['phases']}
for name, art in p['artifacts'].items():
    assert art['produced_by'] in phase_ids, f'{name}.produced_by={art[\"produced_by\"]} not in phases'
    for c in art['consumed_by']:
        assert c in phase_ids, f'{name}.consumed_by={c} not in phases'
print('Valid YAML + all artifact references valid')
"
```

Expected: `Valid YAML + all artifact references valid`

- [ ] **Step 3: コミット**

```bash
git add claude/skills/debug-flow/pipeline.yml
git commit -m "rewrite debug-flow pipeline.yml to v3 with artifact contracts"
```

---

### Task 4: workflow-engine/SKILL.md のオーケストレーションループ更新

**Files:**
- Modify: `claude/skills/workflow-engine/SKILL.md`

- [ ] **Step 1: SKILL.md の Step 4.3 を書き換え**

`claude/skills/workflow-engine/SKILL.md` の `#### 4.3 Phase 実行準備` セクションを以下に置換:

```markdown
#### 4.3 Phase 実行準備
1. Read `$PIPELINE_DIR/{phase.phase_file}`
2. `uses` モジュール注入: phase に `uses` 宣言があれば、`${CLAUDE_SKILL_DIR}/modules/{module}.md` を Read し注入
3. Artifact 解決: `pipeline.yml` の `artifacts` セクションから、`consumed_by` にこのフェーズ ID を含む artifact を全て特定し、Phase Summary チェーンから値を取得
   - `type: file` → Read
   - `type: git_range` → git diff で参照
   - `type: inline` → そのまま使用
4. 前フェーズの concerns/directives を `target_phase` でフィルタし注入
5. `phase_references` を Read（`$PIPELINE_DIR/references/` 内）
```

- [ ] **Step 2: Step 4.5 を書き換え**

`#### 4.5 Audit Gate` セクションを以下に置換:

```markdown
#### 4.5 Audit Gate
modules に `audit` が含まれる場合:
1. Read `${CLAUDE_SKILL_DIR}/modules/audit.md` → プロトコル実行
2. Audit チェックリストの組み立て:
   a. `pipeline.yml` artifacts から、このフェーズが `produced_by` である artifact を特定
   b. 各 artifact の `contract.verification` を収集 → verification リスト
   c. 各 artifact の `contract.validation` を収集 → validation リスト
   d. `$PIPELINE_DIR/done-criteria/{phase.id}.md` を Read
   e. `operations` を収集 → operations リスト
   f. `artifact_validation.{artifact_name}.additional` を validation リストにマージ
3. `audit: required` → phase-auditor に 3 層（verification / validation / operations）を渡す
4. `audit: lite` → エンジン自身が verification + operations を直接検証
5. FAIL → Fix Dispatch → Re-audit（max_retries まで）
```

- [ ] **Step 3: Step 1 の初期化にバージョンチェックを追加**

`### 1. 初期化` セクションの手順 2 を以下に置換:

```markdown
2. `version` フィールドを確認 → 3 以外ならエラー終了
```

- [ ] **Step 4: コミット**

```bash
git add claude/skills/workflow-engine/SKILL.md
git commit -m "update orchestration loop for artifact contract model"
```

---

### Task 5: phase-summary.md に inner_loop_state と validation_record を追加

**Files:**
- Modify: `claude/skills/workflow-engine/modules/phase-summary.md`

- [ ] **Step 1: フォーマットセクションに新フィールドを追加**

`claude/skills/workflow-engine/modules/phase-summary.md` の `## フォーマット` 内の YAML ブロックに以下を追記（`regate_history: []` の前に挿入）:

```yaml
# execute フェーズ専用。status: in_progress の場合のみ有効。
# mid-phase handover 時のサブステップ復帰に使用する。
inner_loop_state:
  current_substep: Impl | TestEnrich | Verify | null
  impl_progress:
    completed_tasks: []
    remaining_tasks: []
    last_commit: <sha>
  loop_iteration: 0
  failure_history: []

# Audit Gate が validation チェックを実行した結果。
# 後続フェーズの auditor が「上流で何が検証済みか」を把握するために使用する。
validation_record:
  - criterion: <question>
    verdict: PASS | FAIL
    evidence: <根拠の要約>
```

- [ ] **Step 2: inner_loop_state の説明セクションを追加**

ファイル末尾に以下を追記:

```markdown
## inner_loop_state

execute フェーズ専用。Inner Loop の進捗状態を記録する。

- `current_substep`: 現在のサブステップ（Impl / TestEnrich / Verify）。null は未開始。
- `impl_progress.completed_tasks`: 完了済みタスク番号のリスト（implementation_plan のタスク番号に対応）。
- `impl_progress.remaining_tasks`: 未完了タスク番号のリスト。
- `impl_progress.last_commit`: 最後にコミットされた SHA。
- `loop_iteration`: Failure Router のループ回数（0 = 初回）。
- `failure_history`: 過去のループでの失敗情報。Failure Router の判定に使用。

resume 時、engine は inner_loop_state を検出し、current_substep から再開する。

## validation_record

Audit Gate が contract.validation + additional の各 question に対して実行した判定結果。

- `criterion`: 検証した question（pipeline.yml contract.validation または done-criteria additional から）。
- `verdict`: PASS または FAIL。
- `evidence`: 判定の根拠の要約（1-2文）。

後続フェーズの auditor は、上流の validation_record を参照することで「この artifact は上流で何が検証済みか」を把握し、フェーズ間の意味的一貫性を判断できる。
```

- [ ] **Step 3: コミット**

```bash
git add claude/skills/workflow-engine/modules/phase-summary.md
git commit -m "add inner_loop_state and validation_record to Phase Summary schema"
```

---

### Task 6: resume.md を全面改定

**Files:**
- Modify: `claude/skills/workflow-engine/modules/resume.md`

- [ ] **Step 1: resume.md を完全書き換え**

`claude/skills/workflow-engine/modules/resume.md` の内容を以下に置換:

```markdown
---
name: resume
description: >-
  Resume Gate プロトコル。handover state からのパイプライン復帰フローを定義する。
  環境復元、artifact 有効性検証、inner_loop_state によるサブステップ再開を含む。
---

# Resume Gate プロトコル

パイプライン起動時の最優先評価。handover state が存在すれば復帰、なければ新規開始。

## Phase 1: State Discovery

### Step 1: project-state.json の検索

1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
2. `pipeline` フィールドが現パイプライン名と一致するか確認
3. 一致 → **Resume Mode**（Phase 2 へ進む）
4. 不一致 or 不在 → **New Mode**（pipeline.yml の最初のフェーズから開始）

### Step 2: pipeline.yml のバージョン確認

1. `pipeline.yml` を Read し `version` フィールドを確認
2. `version: 3` → 以下のプロトコルで実行
3. それ以外 → エラー終了

## Phase 2: Environment Restoration

### Step 3: Worktree 復元

1. `project-state.json` の `artifacts.worktree_path` を確認
2. `git worktree list` で worktree の存在を検証
3. 存在する → `cd` して作業ディレクトリを設定
4. 存在しない → `git worktree add <path> <branch>` で復元
5. ロック競合（`.git/worktrees/<name>/locked` が存在）→ PAUSE（ユーザーに別セッションの終了を依頼）

### Step 4: Artifact 有効性検証

1. `current_phase` が `consumed_by` として参照する artifact を `pipeline.yml` artifacts セクションから特定
2. 各 artifact の `type` に応じた存在確認:
   - `file` → Glob で `pattern` に一致するファイルの存在チェック
   - `git_range` → `git rev-parse <start> <end>` で到達可能性を確認
   - `inline` → Phase Summary から直接取得（常に有効）
3. 無効な artifact がある → PAUSE（無効な artifact 名と原因を提示）

## Phase 3: Context Reconstruction

### Step 5: concerns/directives 抽出

1. 全完了フェーズの Phase Summary を走査
2. `concerns` と `directives` から `target_phase` = `current_phase` のものを抽出
3. 注入対象としてバッファ

### Step 6: validation_record 累積

1. 全完了フェーズの `validation_record` を収集
2. audit context に含める（後続の Audit Gate が「上流で検証済みの項目」を把握するため）

## Phase 4: Phase Dispatch

### Step 7: inner_loop_state 判定

execute フェーズの場合のみ:

1. Phase Summary の `inner_loop_state` を確認
2. `inner_loop_state` が存在し `current_substep` が null でない場合:
   - `Impl` → `remaining_tasks` のみで `subagent-driven-development` を起動。`completed_tasks` に該当するタスクはスキップ
   - `TestEnrich` → TestEnrich から再開。`impl_progress` を TestEnrich 入力コンテキストに注入
   - `Verify` → Verify から再開。`failure_history` を Failure Router に注入
3. `inner_loop_state` が存在しない or `current_substep` が null → フェーズ先頭から実行

### Step 8: ユーザー承認

1. 復元した環境情報を提示:
   - worktree パス、ブランチ名
   - 有効な artifact 一覧
   - concerns/directives の件数
2. `inner_loop_state` がある場合は再開ポイントも提示:
   - 「execute Sub-step {current_substep} から再開。タスク {completed_tasks} 完了済み、残り {remaining_tasks}」
3. ユーザー承認を得て `current_phase` から再開
```

- [ ] **Step 2: コミット**

```bash
git add claude/skills/workflow-engine/modules/resume.md
git commit -m "rewrite resume.md with 4-phase protocol, worktree restore, and inner_loop_state"
```

---

### Task 7: context-budget.md に Inner Loop チェックポイントを追加

**Files:**
- Modify: `claude/skills/workflow-engine/modules/context-budget.md`

- [ ] **Step 1: Inner Loop チェックポイントセクションを追加**

`claude/skills/workflow-engine/modules/context-budget.md` の末尾に以下を追記:

```markdown
## Inner Loop チェックポイント

execute フェーズの Inner Loop 内では、以下のタイミングでコンテキスト予算を評価する:

1. **Sub-step 1 (Impl) 完了時** — 全タスクの実装完了後、TestEnrich 開始前
2. **Failure Router の各 iteration 開始時** — TestEnrich → Verify ループの各回の開始前

チェックポイントで残量が critical 閾値（orchestrator 予算の 50%）を下回った場合:

1. Phase Summary の `inner_loop_state` に現在の状態を記録:
   - `current_substep`: 次に実行すべきサブステップ
   - `impl_progress`: 完了/未完了タスクのリスト
   - `loop_iteration`: 現在のループ回数
   - `failure_history`: 直近の失敗情報
2. Phase Summary の `status` を `in_progress` に設定
3. `/handover` を実行
```

- [ ] **Step 2: コミット**

```bash
git add claude/skills/workflow-engine/modules/context-budget.md
git commit -m "add inner loop checkpoints to context-budget module"
```

---

### Task 8: inner-loop.md に resume 処理と reproduction_test 参照を追加

**Files:**
- Modify: `claude/skills/workflow-engine/modules/inner-loop.md`

- [ ] **Step 1: TestEnrich 入力コンテキストに reproduction_test を追加**

`claude/skills/workflow-engine/modules/inner-loop.md` の `## 3. TestEnrich 実行手順` 内の `### 入力コンテキスト` の YAML ブロックを以下に置換:

```yaml
test_enrich_context:
  requirements_source:
    feature-dev: spec_file + implementation_plan
    debug-flow:  rca_report + fix_plan
  existing_tests:
    - git diff で追加/変更されたテストファイル
    - 関連する既存テストファイル（impact 範囲）
    - reproduction_test（debug-flow の場合、pipeline.yml artifacts から解決）
  implementation:
    - git diff の code_changes 範囲
  required_levels:
    - unit: true
    - integration: true
```

- [ ] **Step 2: resume セクションを追加**

ファイル末尾（`## 4. Failure Router` セクションの後）に以下を追記:

```markdown
## 5. Resume からの再開

handover 後に resume.md が `inner_loop_state` を検出した場合、以下のフローで再開する。

### Impl から再開

`current_substep: Impl` の場合:

1. `impl_progress.remaining_tasks` を implementation_plan/fix_plan と照合
2. `completed_tasks` に該当するタスクをスキップ
3. `remaining_tasks` のみで `subagent-driven-development` を起動
4. `last_commit` から git diff で完了済み実装を確認（存在検証）
5. 全 remaining_tasks 完了後、通常フローで TestEnrich に進む

### TestEnrich から再開

`current_substep: TestEnrich` の場合:

1. `impl_progress` の全タスクが実装済みであることを git diff で確認
2. TestEnrich の入力コンテキストを構築（セクション3の手順に従う）
3. TestEnrich を先頭から実行（トレーサビリティマップ作成から）

### Verify から再開

`current_substep: Verify` の場合:

1. `failure_history` を Failure Router に注入
2. `loop_iteration` を復元
3. Verify を先頭から実行（全テストスイート実行から）
```

- [ ] **Step 3: コミット**

```bash
git add claude/skills/workflow-engine/modules/inner-loop.md
git commit -m "add resume handling and reproduction_test to inner-loop module"
```

---

### Task 9: execute.md の簡素化（feature-dev + debug-flow）

**Files:**
- Modify: `claude/skills/feature-dev/phases/execute.md`
- Modify: `claude/skills/debug-flow/phases/execute.md`

- [ ] **Step 1: feature-dev execute.md の書き換え**

`claude/skills/feature-dev/phases/execute.md` の内容を以下に置換:

```markdown
---
phase: 5
phase_name: execute
phase_references: []
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---

## 実行手順

inner-loop プロトコル（engine が `uses: [inner-loop]` 経由で注入済み）に従い、Impl → TestEnrich → Verify の3サブステップを実行する。詳細は inner-loop プロトコルを参照。

### Resume 時

inner_loop_state が Phase Summary に存在する場合、inner-loop プロトコルのセクション5「Resume からの再開」に従い、記録されたサブステップから再開する。

### Evidence Collection

design Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果

## Phase Summary テンプレート

```yaml
artifacts:
  code_changes:
    type: git_range
    value: "<first_commit>..<last_commit>"
    branch: "<branch_name>"
  test_results:
    type: inline
    value: "<N passed, N failed, coverage N%>"
  evidence_collection:
    type: file
    value: "<evidence ディレクトリパス>"
```
```

- [ ] **Step 2: debug-flow execute.md の書き換え**

`claude/skills/debug-flow/phases/execute.md` の内容を以下に置換:

```markdown
---
phase: 4
phase_name: execute
phase_references: []
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---

## 実行手順

inner-loop プロトコル（engine が `uses: [inner-loop]` 経由で注入済み）に従い、Impl → TestEnrich → Verify の3サブステップを実行する。詳細は inner-loop プロトコルを参照。

### Resume 時

inner_loop_state が Phase Summary に存在する場合、inner-loop プロトコルのセクション5「Resume からの再開」に従い、記録されたサブステップから再開する。

### Evidence Collection

rca Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果

## Phase Summary テンプレート

```yaml
artifacts:
  code_changes:
    type: git_range
    value: "<first_commit>..<last_commit>"
    branch: "<branch_name>"
  test_results:
    type: inline
    value: "<N passed, N failed, coverage N%>"
```
```

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/phases/execute.md claude/skills/debug-flow/phases/execute.md
git commit -m "simplify execute.md by delegating sub-step details to inner-loop module"
```

---

### Task 10: 全 phase.md から requires_artifacts を削除

**Files:**
- Modify: `claude/skills/feature-dev/phases/design.md`
- Modify: `claude/skills/feature-dev/phases/spec-review.md`
- Modify: `claude/skills/feature-dev/phases/plan.md`
- Modify: `claude/skills/feature-dev/phases/plan-review.md`
- Modify: `claude/skills/feature-dev/phases/accept-test.md`
- Modify: `claude/skills/feature-dev/phases/doc-audit.md`
- Modify: `claude/skills/feature-dev/phases/review.md`
- Modify: `claude/skills/feature-dev/phases/integrate.md`
- Modify: `claude/skills/debug-flow/phases/rca.md`
- Modify: `claude/skills/debug-flow/phases/fix-plan.md`
- Modify: `claude/skills/debug-flow/phases/fix-plan-review.md`
- Modify: `claude/skills/debug-flow/phases/accept-test.md`
- Modify: `claude/skills/debug-flow/phases/doc-audit.md`
- Modify: `claude/skills/debug-flow/phases/review.md`
- Modify: `claude/skills/debug-flow/phases/integrate.md`

Note: execute.md は Task 9 で既に処理済み。

- [ ] **Step 1: 全 phase.md から requires_artifacts 行を削除**

各ファイルの frontmatter から `requires_artifacts:` とその値（配列）を削除する。本文中の `requires_artifacts の XXX を Read` という指示は、`pipeline.yml artifacts から解決された XXX を Read` に書き換える。

feature-dev/phases/design.md: `requires_artifacts: []` を削除（値が空なので本文変更なし）

feature-dev/phases/spec-review.md: `requires_artifacts:\n  - spec_file` を削除。本文の「`requires_artifacts` の `spec_file` を Read」を「`spec_file` を Read（engine が artifacts から解決）」に変更。

feature-dev/phases/plan.md: 同様に `requires_artifacts:\n  - spec_file` を削除。本文を同様に変更。

feature-dev/phases/plan-review.md: `requires_artifacts:\n  - implementation_plan\n  - spec_file` を削除。本文の「`requires_artifacts` の `implementation_plan` と `spec_file` を Read」を「`implementation_plan` と `spec_file` を Read（engine が artifacts から解決）」に変更。

feature-dev/phases/accept-test.md: `requires_artifacts:\n  - code_changes` を削除。本文に requires_artifacts の直接参照がないため変更なし。

feature-dev/phases/doc-audit.md: `requires_artifacts:\n  - code_changes` を削除。本文変更なし。

feature-dev/phases/review.md: `requires_artifacts:\n  - code_changes\n  - test_results` を削除。本文の「`requires_artifacts` の `code_changes` から」を「`code_changes` から」に変更。

feature-dev/phases/integrate.md: `requires_artifacts:\n  - code_changes` を削除。本文変更なし。

debug-flow/phases/rca.md: `requires_artifacts: []` を削除。本文変更なし。

debug-flow/phases/fix-plan.md: `requires_artifacts:\n  - rca_report` を削除。本文を同様に変更。

debug-flow/phases/fix-plan-review.md: `requires_artifacts:\n  - fix_plan\n  - rca_report` を削除。本文を同様に変更。

debug-flow の accept-test.md, doc-audit.md, review.md, integrate.md は feature-dev と同一ファイル（シンボリックリンクまたはコピー）の場合は一度の変更で済む。別ファイルの場合は feature-dev と同様に変更。

- [ ] **Step 2: requires_artifacts が残っていないことを検証**

```bash
grep -r "requires_artifacts" claude/skills/feature-dev/phases/ claude/skills/debug-flow/phases/
```

Expected: 出力なし（grep が何も返さない）

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/phases/ claude/skills/debug-flow/phases/
git commit -m "remove requires_artifacts from all phase frontmatters (now resolved from pipeline.yml artifacts)"
```

---

### Task 11: feature-dev done-criteria の再構成（design, spec-review, plan）

**Files:**
- Modify: `claude/skills/feature-dev/done-criteria/design.md`
- Modify: `claude/skills/feature-dev/done-criteria/spec-review.md`
- Modify: `claude/skills/feature-dev/done-criteria/plan.md`

- [ ] **Step 1: design done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/design.md` の内容を以下に置換:

```markdown
---
name: design
max_retries: 3
audit: required
---

## Operations

### DSN-OP1: worktree 作成済み + ベースラインテスト通過
- **layer**: verification
- **check**: automated
- **verification**:
  1. `git worktree list` で worktree が存在することを確認（出力行数が2以上）
  2. プロジェクトのテストコマンドを実行し exit code が 0 であることを確認
- **pass_condition**: worktree 存在 AND テスト exit code = 0

### DSN-OP2: コードベース並列探索が実行された
- **layer**: verification
- **check**: automated
- **verification**: brainstorming-supplement S1 の3エージェント（code-explorer, code-architect, impact-analyzer）の実行記録を確認
- **pass_condition**: 3エージェント全ての実行記録が存在

## Artifact Validation

### spec_file

additional:
  - question: "代替案が検討され、各案に採用/不採用の理由が付記されているか"
    severity: quality
  - question: "主要な設計判断とその根拠が設計書に記載されているか"
    severity: blocker
  - question: "Investigation Record の6項目（prerequisites, impact_scope, reverse_dependencies, shared_state, implicit_contracts, side_effect_risks）が実質的な内容を持つか"
    severity: blocker
```

- [ ] **Step 2: spec-review done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/spec-review.md` の内容を以下に置換:

```markdown
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
```

- [ ] **Step 3: plan done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/plan.md` の内容を以下に置換:

```markdown
---
name: plan
max_retries: 3
audit: required
---

## Operations

（なし — plan フェーズにはフェーズ固有の運用チェックはない）

## Artifact Validation

### implementation_plan

additional:
  - question: "タスク粒度が sub-agent で実行可能か（各タスクのステップ数が10以下、変更対象モジュールが3未満）"
    severity: quality
  - question: "タスク依存関係に循環がなく、依存先タスク ID が全て計画書内に存在するか"
    severity: blocker

### test_cases

additional:
  - question: "各テストケースに Given/When/Then の3要素が全て含まれ、Then 句に検証可能な期待値があるか"
    severity: blocker
```

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/done-criteria/design.md claude/skills/feature-dev/done-criteria/spec-review.md claude/skills/feature-dev/done-criteria/plan.md
git commit -m "restructure design/spec-review/plan done-criteria to operations + artifact_validation"
```

---

### Task 12: feature-dev done-criteria の再構成（plan-review, execute, accept-test, doc-audit, review, integrate）

**Files:**
- Modify: `claude/skills/feature-dev/done-criteria/plan-review.md`
- Modify: `claude/skills/feature-dev/done-criteria/execute.md`
- Modify: `claude/skills/feature-dev/done-criteria/accept-test.md`
- Modify: `claude/skills/feature-dev/done-criteria/doc-audit.md`
- Modify: `claude/skills/feature-dev/done-criteria/review.md`
- Modify: `claude/skills/feature-dev/done-criteria/integrate.md`

- [ ] **Step 1: plan-review done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/plan-review.md` の内容を以下に置換:

```markdown
---
name: plan-review
max_retries: 3
audit: required
---

## Operations

### PLR-OP1: レビューが全3観点で実行された
- **layer**: verification
- **check**: automated
- **verification**: 3観点（clarity, feasibility, consistency）の実行記録を確認
- **pass_condition**: 3観点全ての実行記録が存在

### PLR-OP2: コンセンサス findings が全て解消済み
- **layer**: verification
- **check**: automated
- **verification**: severity: consensus の findings を抽出し、未解消件数をカウント
- **pass_condition**: 未解消件数 = 0

## Artifact Validation

### implementation_plan

additional:
  - question: "計画書と設計書の整合性が保たれているか（コンポーネント名、ファイルパス、データ型、インターフェースの一致）"
    severity: blocker
  - question: "各タスクの完了条件が検証可能な形で記述されているか（主観語なし、数値閾値またはパターンマッチ形式）"
    severity: blocker
```

- [ ] **Step 2: execute done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/execute.md` の内容を以下に置換:

```markdown
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
```

- [ ] **Step 3: accept-test done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/accept-test.md` の内容を以下に置換:

```markdown
---
name: accept-test
max_retries: 3
audit: required
---

## Operations

### ACT-OP1: 全 Acceptance Test ステップが PASS
- **layer**: verification
- **check**: automated
- **verification**: テスト結果ファイルの全ステップが PASS であることを確認
- **pass_condition**: FAIL ステップが 0 件

### ACT-OP2: flaky test が未検出または報告済み
- **layer**: verification
- **check**: automated
- **verification**: 同一ステップの再実行で結果が変わったケースを検出
- **pass_condition**: flaky 未検出、または全件が報告リストに記録済み

### ACT-OP3: テスト実行証跡が有効
- **layer**: verification
- **check**: automated
- **verification**: accept-test-report.md の存在、プロジェクト種別に応じた証跡（スクリーンショット、ログ等）の存在を確認
- **pass_condition**: レポート + 証跡が存在

## Artifact Validation

### accept_test_results

additional: []
```

- [ ] **Step 4: doc-audit done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/doc-audit.md` の内容を以下に置換:

```markdown
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
```

- [ ] **Step 5: review done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/review.md` の内容を以下に置換:

```markdown
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
```

- [ ] **Step 6: integrate done-criteria の書き換え**

`claude/skills/feature-dev/done-criteria/integrate.md` の内容を以下に置換:

```markdown
---
name: integrate
max_retries: 3
audit: lite
---

## Operations

### INT-OP1: ユーザーが統合方法を選択済み
- **layer**: verification
- **check**: automated
- **verification**: 統合方法の選択値が wt-merge/pr/branch-keep/discard のいずれか
- **pass_condition**: 有効な選択値が存在

### INT-OP2: 選択されたアクションが完了
- **layer**: verification
- **check**: automated
- **verification**: wt-merge→マージコミット存在+worktree削除。pr→PR URL取得成功+worktree削除。branch-keep→ブランチ存在。discard→worktree削除。
- **pass_condition**: 選択された方法に応じた完了条件を満たす

## Artifact Validation

### merged_branch

additional: []
```

- [ ] **Step 7: コミット**

```bash
git add claude/skills/feature-dev/done-criteria/
git commit -m "restructure remaining feature-dev done-criteria to operations + artifact_validation"
```

---

### Task 13: debug-flow done-criteria の再構成

**Files:**
- Modify: `claude/skills/debug-flow/done-criteria/rca.md`
- Modify: `claude/skills/debug-flow/done-criteria/fix-plan.md`
- Modify: `claude/skills/debug-flow/done-criteria/fix-plan-review.md`
- Modify: `claude/skills/debug-flow/done-criteria/execute.md`
- Modify: `claude/skills/debug-flow/done-criteria/accept-test.md`
- Modify: `claude/skills/debug-flow/done-criteria/doc-audit.md`
- Modify: `claude/skills/debug-flow/done-criteria/review.md`
- Modify: `claude/skills/debug-flow/done-criteria/integrate.md`

- [ ] **Step 1: rca done-criteria の書き換え**

`claude/skills/debug-flow/done-criteria/rca.md` の内容を以下に置換:

```markdown
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

### reproduction_test

additional: []
```

- [ ] **Step 2: fix-plan done-criteria の書き換え**

`claude/skills/debug-flow/done-criteria/fix-plan.md` の内容を以下に置換:

```markdown
---
name: fix-plan
max_retries: 3
audit: required
---

## Operations

（なし）

## Artifact Validation

### fix_plan

additional:
  - question: "Fix Strategy の全項目がタスクに分解されているか"
    severity: blocker
  - question: "タスク依存関係に循環がなく、依存先タスク ID が全て計画書内に存在するか"
    severity: blocker

### test_cases

additional:
  - question: "各テストケースに Given/When/Then の3要素が全て含まれ、Then 句に検証可能な期待値があるか"
    severity: blocker
```

- [ ] **Step 3: fix-plan-review done-criteria の書き換え**

`claude/skills/debug-flow/done-criteria/fix-plan-review.md` の内容を以下に置換:

```markdown
---
name: fix-plan-review
max_retries: 3
audit: required
---

## Operations

### FPR-OP1: レビューが全3観点で実行された
- **layer**: verification
- **check**: automated
- **verification**: 3観点（clarity, feasibility, consistency）の実行記録を確認
- **pass_condition**: 3観点全ての実行記録が存在

### FPR-OP2: コンセンサス findings が全て解消済み
- **layer**: verification
- **check**: automated
- **verification**: severity: consensus の findings を抽出し、未解消件数をカウント
- **pass_condition**: 未解消件数 = 0

## Artifact Validation

### fix_plan

additional:
  - question: "計画書と RCA Report の整合性が保たれているか（根本原因、影響範囲、修正方針の一致）"
    severity: blocker
  - question: "各タスクの完了条件が検証可能な形で記述されているか（主観語なし）"
    severity: blocker
```

- [ ] **Step 4: debug-flow execute done-criteria の書き換え**

`claude/skills/debug-flow/done-criteria/execute.md` の内容を以下に置換:

```markdown
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
```

- [ ] **Step 5: debug-flow の共通 done-criteria（accept-test, doc-audit, review, integrate）の書き換え**

debug-flow の accept-test.md, doc-audit.md, review.md, integrate.md は feature-dev と同一構造。feature-dev の Task 12 で作成した内容と同一にする。

各ファイルを feature-dev 版の内容にコピー:

```bash
cp claude/skills/feature-dev/done-criteria/accept-test.md claude/skills/debug-flow/done-criteria/accept-test.md
cp claude/skills/feature-dev/done-criteria/doc-audit.md claude/skills/debug-flow/done-criteria/doc-audit.md
cp claude/skills/feature-dev/done-criteria/review.md claude/skills/debug-flow/done-criteria/review.md
cp claude/skills/feature-dev/done-criteria/integrate.md claude/skills/debug-flow/done-criteria/integrate.md
```

- [ ] **Step 6: コミット**

```bash
git add claude/skills/debug-flow/done-criteria/
git commit -m "restructure all debug-flow done-criteria to operations + artifact_validation"
```

---

### Task 14: 最終検証

**Files:** None (read-only verification)

- [ ] **Step 1: 全 pipeline.yml の artifact chain 整合性を検証**

```bash
for f in claude/skills/feature-dev/pipeline.yml claude/skills/debug-flow/pipeline.yml; do
  echo "=== $f ==="
  python3 -c "
import yaml
p = yaml.safe_load(open('$f'))
phase_ids = {ph['id'] for ph in p['phases']}
errors = []
for name, art in p['artifacts'].items():
    if art['produced_by'] not in phase_ids:
        errors.append(f'{name}.produced_by={art[\"produced_by\"]} not in phases')
    for c in art['consumed_by']:
        if c not in phase_ids:
            errors.append(f'{name}.consumed_by={c} not in phases')
    if art['type'] == 'file' and 'pattern' not in art:
        errors.append(f'{name}: type=file but no pattern')
if errors:
    for e in errors: print(f'ERROR: {e}')
else:
    print('OK')
"
done
```

Expected: 両方 `OK`

- [ ] **Step 2: requires_artifacts の完全除去を確認**

```bash
grep -r "requires_artifacts" claude/skills/feature-dev/phases/ claude/skills/debug-flow/phases/ && echo "FAIL: requires_artifacts still present" || echo "OK: no requires_artifacts found"
```

Expected: `OK: no requires_artifacts found`

- [ ] **Step 3: done-criteria に depends_on_artifacts が残っていないことを確認**

```bash
grep -r "depends_on_artifacts" claude/skills/feature-dev/done-criteria/ claude/skills/debug-flow/done-criteria/ && echo "FAIL: depends_on_artifacts still present" || echo "OK: no depends_on_artifacts found"
```

Expected: `OK: no depends_on_artifacts found`

- [ ] **Step 4: done-criteria に旧パス参照が残っていないことを確認**

```bash
grep -r "docs/plans/.*-design" claude/skills/feature-dev/done-criteria/ claude/skills/debug-flow/done-criteria/ && echo "FAIL: old path references found" || echo "OK: no old path references"
```

Expected: `OK: no old path references`

- [ ] **Step 5: version フィールドが全て 3 であることを確認**

```bash
grep "^version:" claude/skills/feature-dev/pipeline.yml claude/skills/debug-flow/pipeline.yml
```

Expected:
```
claude/skills/feature-dev/pipeline.yml:version: 3
claude/skills/debug-flow/pipeline.yml:version: 3
```

- [ ] **Step 6: SKILL.md に v2 参照が残っていないことを確認**

```bash
grep -i "v2\|version.*2" claude/skills/workflow-engine/SKILL.md && echo "FAIL" || echo "OK: no v2 references"
```

Expected: `OK: no v2 references`
