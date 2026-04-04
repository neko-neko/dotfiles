# Artifact Contract Model Design

## 概要

workflow-engine の artifact lifecycle を一元化し、Verification（形式検証）と Validation（意味検証）を構造的に分離する。

## 背景

### 検出された問題

コンテキスト伝搬の擬似再現検証（2026-04-04）により、以下の構造的問題が判明:

1. **Artifact 定義の散在**: produces (pipeline.yml)、requires_artifacts (phase.md)、depends_on_artifacts (done-criteria) の3箇所に分散し、パス不整合が発生
2. **Validation の不在**: done-criteria が形式検証（ファイル存在、テスト通過）に偏り、意味検証（ユーザー要求との整合性）がない
3. **Handover 時の状態欠落**: Inner Loop のサブステップ進捗が記録されず、mid-phase 中断からの復帰ができない
4. **Pipeline 間の非対称性**: debug-flow の artifact 追跡が feature-dev より不完全

### 将来構想: CLI 切り出し

workflow-engine を超軽量ワークフローエンジン CLI として切り出す構想がある:

| 時間軸 | Verification | Validation |
|--------|-------------|------------|
| 現在 | LLM | 不在 |
| 将来 | CLI | LLM |

本設計はこの分離を型レベルで保証する。

## 設計

### 1. pipeline.yml — Artifact 型定義

pipeline.yml に `artifacts` セクションを導入し、成果物のライフサイクルを一元管理する。

```yaml
pipeline: feature-dev
version: 3

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
```

#### phases セクションの簡素化

```yaml
phases:
  - id: design
    phase_file: phases/design.md
    # requires_artifacts は artifacts.*.consumed_by から自動解決
    # done_criteria は規約で done-criteria/{phase_id}.md を自動解決

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
```

#### 解決ルール

- **artifact 解決**: engine は `artifacts.*.consumed_by` にフェーズ ID が含まれる artifact を特定し、Phase Summary チェーンから値を取得する
- **done-criteria 解決**: `done-criteria/{phase_id}.md` を規約で自動解決（phases への明示宣言不要）
- **produced_by の順序保証**: produced_by が consumed_by より前のフェーズであることを pipeline schema で静的検証

### 2. done-criteria の再構成

done-criteria ファイルは **フェーズ固有の追加基準のみ** を担当する。artifact の verification/validation は pipeline.yml の contract から engine が自動生成する。

```yaml
# done-criteria/design.md
---
name: design
max_retries: 3
audit: required
---

# Phase Operations
# フェーズの実行プロセスに関する基準（artifact contract に含まれない）

operations:
  DSN-OP1:
    description: "worktree 作成済み + ベースラインテスト通過"
    layer: verification
    check: automated

  DSN-OP2:
    description: "コードベース並列探索（S1）が実行された"
    layer: verification
    check: automated

# Artifact Validation Additions
# pipeline.yml の contract.validation に追加するフェーズ固有の検証

artifact_validation:
  spec_file:
    additional:
      - question: "代替案が検討され、各案に採用/不採用の理由が付記されているか"
        severity: quality
      - question: "主要な設計判断とその根拠が設計書に記載されているか"
        severity: blocker
```

#### engine の Audit Gate 組み立てフロー

```
1. pipeline.yml artifacts から、このフェーズが produced_by である artifact を特定
2. 各 artifact の contract.verification を収集 → verification リスト
3. 各 artifact の contract.validation を収集 → validation リスト
4. done-criteria/{phase_id}.md を Read
5. operations を収集 → operations リスト
6. artifact_validation.{artifact_name}.additional を validation リストにマージ
7. phase-auditor に渡す:
   - verification: 機械的に実行（将来は CLI）
   - validation: LLM が upstream artifact / user_request / codebase と照合
   - operations: フェーズ固有の運用チェック
```

### 3. Phase Summary スキーマ拡張

```yaml
# Phase Summary v3
phase_id: <phase_id>
phase_name: <name>
status: completed | in_progress | failed
timestamp: <ISO8601>
attempt: <N>
audit_verdict: PASS | FAIL | null

artifacts:
  <name>:
    type: file | git_range | inline
    value: <参照先>

# 監査証跡。後続フェーズへの自動注入はしない。
# 成果物に反映すべき判断は artifact 内に記載されているべき
# （contract.validation + additional で検証される）
decisions: []

concerns:
  - target_phase: <phase_id>
    content: <内容>
directives:
  - target_phase: <phase_id>
    content: <内容>

# NEW: execute フェーズ専用。status: in_progress の場合のみ有効
inner_loop_state:
  current_substep: Impl | TestEnrich | Verify | null
  impl_progress:
    completed_tasks: []
    remaining_tasks: []
    last_commit: <sha>
  loop_iteration: 0
  failure_history: []

# NEW: Audit Gate が validation チェックを実行した結果
# 後続フェーズの auditor が「上流で何が検証済みか」を把握するために使用
validation_record:
  - criterion: <question>
    verdict: PASS | FAIL
    evidence: <根拠の要約>

evidence: []
regate_history: []
```

### 4. resume.md プロトコル拡張

```markdown
# Resume Gate Protocol v3

## Phase 1: State Discovery

Step 1: project-state.json を検索
  - .claude/handover/{branch}/ を走査
  - pipeline フィールドが現パイプライン名と一致するか確認
  - 不一致 or 不在 → New Mode

Step 2: pipeline.yml を Read し version: 3 を確認

## Phase 2: Environment Restoration

Step 3: Worktree 復元
  - project-state.json の artifacts.worktree_path を確認
  - git worktree list で存在を検証
  - 存在する → cd して作業ディレクトリを設定
  - 存在しない → git worktree add <path> <branch> で復元
  - ロック競合 → PAUSE（ユーザーに別セッションの終了を依頼）

Step 4: Artifact 有効性検証
  - current_phase が consumed_by として参照する artifact を
    pipeline.yml artifacts セクションから特定
  - type に応じた存在確認:
    - file → Glob で存在チェック
    - git_range → git rev-parse で到達可能性を確認
    - inline → Phase Summary から直接取得（常に有効）
  - 無効な artifact → PAUSE（原因を提示）

## Phase 3: Context Reconstruction

Step 5: concerns/directives 抽出
  - 全完了フェーズの Phase Summary から target_phase = current_phase でフィルタ

Step 6: validation_record 累積
  - 全完了フェーズの validation_record を収集
  - audit context に含める

## Phase 4: Phase Dispatch

Step 7: inner_loop_state 判定（execute フェーズのみ）
  - inner_loop_state が存在する場合:
    - current_substep を確認
    - Impl → remaining_tasks のみで subagent-driven-development を起動
    - TestEnrich → TestEnrich から再開
    - Verify → Verify から再開（failure_history を注入）
  - inner_loop_state が null → フェーズ先頭から実行

Step 8: ユーザー承認
  - 復元した環境情報を提示
  - inner_loop_state がある場合は再開ポイントも提示
  - 承認を得て current_phase から再開
```

### 5. 既存ファイルへの影響

#### pipeline schema

| ファイル | 変更 |
|---------|------|
| `workflow-engine/schema/pipeline.v2.schema.json` | **削除** |
| `workflow-engine/schema/pipeline.schema.json` | 新規作成。artifacts セクション、contract 定義を含む |

#### pipeline 定義

| ファイル | 変更 |
|---------|------|
| `feature-dev/pipeline.yml` | artifacts セクション追加、phases 簡素化、version: 3 |
| `debug-flow/pipeline.yml` | 同上 + reproduction_test, test_cases 追加 |

#### workflow-engine modules

| ファイル | 変更 |
|---------|------|
| `workflow-engine/SKILL.md` | 4.3 artifact 解決を contract ベースに、4.5 Audit Gate の3層化 |
| `workflow-engine/modules/phase-summary.md` | inner_loop_state, validation_record 追加 |
| `workflow-engine/modules/resume.md` | 全面改定（4 Phase 構造） |
| `workflow-engine/modules/context-budget.md` | Inner Loop 内チェックポイント追加 |
| `workflow-engine/modules/inner-loop.md` | resume 時の remaining_tasks 処理追加、TestEnrich 入力に reproduction_test 追加（debug-flow 時） |

#### phase ファイル

| ファイル | 変更 |
|---------|------|
| `feature-dev/phases/*.md` (全9) | frontmatter から requires_artifacts 削除 |
| `debug-flow/phases/*.md` (全8) | 同上 |
| `feature-dev/phases/execute.md` | Sub-step 重複削減（inner-loop.md への委譲）、resume 手順追加 |
| `debug-flow/phases/execute.md` | 同上 |

#### done-criteria

| ファイル | 変更 |
|---------|------|
| `feature-dev/done-criteria/*.md` (全9) | operations + artifact_validation 構造に再編 |
| `debug-flow/done-criteria/*.md` (全8) | 同上 |

### 6. スコープ外

- decisions の伝播メカニズム追加（artifact 品質で解決）
- evidence-catalog の改定
- regate 戦略ファイルの変更
- integration hooks の変更（linear-sync 等）

### 7. リスク

- **done-criteria 全ファイルの再編**: 17ファイル。各基準を verification / validation / operations に分類する判断が必要
- **contract.validation の粒度**: question と against の記述が粗すぎると形式的な検証に戻り、細かすぎると保守コストが上がる
