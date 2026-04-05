---
name: workflow-engine
description: >-
  パイプライン型ワークフローの汎用オーケストレーションエンジン。
  Phase Dispatch, Audit Gate, Regate, Handover, Integration Hooks を駆動する。
  feature-dev, debug-flow 等のパイプラインスキルから呼び出される。
user-invocable: false
---

# Workflow Engine

パイプライン型ワークフローの汎用オーケストレーションエンジン。

## 引数

- `$ARGUMENTS[0]`: パイプラインスキルのディレクトリパス（$PIPELINE_DIR として使用）
- `$ARGUMENTS[1]`: パースされたフラグ（JSON）
- `$ARGUMENTS[2]`: タスク記述

## パス解決ルール

| パス | 解決先 | 用途 |
|-----|-------|------|
| `${CLAUDE_SKILL_DIR}` | `workflow-engine/` | modules/*.md, schema/ の読み込み |
| `$PIPELINE_DIR` | `$ARGUMENTS[0]` | pipeline.yml, phases/, done-criteria/, regate/, references/ |

## オーケストレーションループ

### 1. 初期化

1. Read `$PIPELINE_DIR/pipeline.yml`
2. `version` フィールドを確認 → 3 以外ならエラー終了
3. `modules` 宣言を解析 → 使用モジュールを特定
4. `pipeline` フィールドからパイプライン名を取得
5. `integrations` を解析 → enabled_by フラグが有効なインテグレーションを特定
6. フラグ展開（$ARGUMENTS[1] の JSON をパース）

### 2. Resume Gate

modules に `resume` が含まれる場合:
- Read `${CLAUDE_SKILL_DIR}/modules/resume.md` → プロトコル実行
- handover state があれば復帰、なければ New Mode

### 3. Integration Hooks: on_pipeline_start

有効なインテグレーションの `on_pipeline_start` フックを発火。

### 4. Phase Dispatch Loop

`pipeline.yml.phases` の各フェーズを順次実行:

#### 4.1 Skip 評価
- `skip: true` → スキップ
- `skip_unless: <flag>` → フラグ未指定ならスキップ
- いずれにも該当しない → 実行

#### 4.2 Integration Hooks: on_phase_start
有効なインテグレーションの `on_phase_start` フックを発火。

#### 4.3 Phase 実行準備
1. Read `$PIPELINE_DIR/{phase.phase_file}`
2. `uses` モジュール注入: phase に `uses` 宣言があれば、`${CLAUDE_SKILL_DIR}/modules/{module}.md` を Read し注入
3. Artifact 解決: `pipeline.yml` の `artifacts` セクションから、`consumed_by` にこのフェーズ ID を含む artifact を全て特定し、Phase Summary チェーンから値を取得
   - `type: file` → Read
   - `type: git_range` → git diff で参照
   - `type: inline` → そのまま使用
4. 前フェーズの concerns/directives を `target_phase` でフィルタし注入
5. `phase_references` を Read（`$PIPELINE_DIR/references/` 内）

#### 4.4 Phase 実行
phase.md の指示に従いフェーズを実行する。

#### 4.5 Audit Gate
modules に `audit` が含まれる場合:
1. Read `${CLAUDE_SKILL_DIR}/modules/audit.md` → プロトコル実行
2. Audit チェックリストの組み立て:
   a. `pipeline.yml` artifacts から、このフェーズが `produced_by` である artifact を特定
   b. 各 artifact の `contract.verification` を収集 → verification リスト
   c. 各 artifact の `contract.validation` を収集 → validation リスト
   d. `$PIPELINE_DIR/done-criteria/{phase.id}.md` を Read
   e. `operations` を収集 → operations リスト
   f. done-criteria の `artifact_validation` セクションを処理:
      - (f1) `### <name>` サブセクションで `<name>` がこのフェーズの produced artifact に含まれる場合: `additional` を `<name>.contract.validation` にマージ
      - (f2) `### <name>` サブセクションで `audit_target: <upstream_name>` が宣言されている場合: `additional` を `<upstream_name>.contract.validation` にこのフェーズの validation として合流する（評価タイミングの詳細は `modules/audit.md` §2.1 参照）
      - (f3) (f1) にも (f2) にも該当しないサブセクションは warning を発しスキップ（silent ignore を禁止）
      - (f4) `audit_target` が Phase N の produced artifact を指す場合はエラー（audit_target は非-produced 上流 artifact 専用）
      - (f5) `audit_target` が pipeline.yml の artifacts に存在しない artifact を指す場合はエラー
3. `audit: required` → phase-auditor に 3 層（verification / validation / operations）を渡す
4. `audit: lite` → エンジン自身が verification + operations を直接検証
5. FAIL → Fix Dispatch → Re-audit（max_retries まで）

#### 4.6 Phase Summary 生成
modules に `phase-summary` が含まれる場合:
- Read `${CLAUDE_SKILL_DIR}/modules/phase-summary.md` → フォーマットに従い生成

#### 4.7 Handover 判定
modules に `context-budget` が含まれる場合:
- Read `${CLAUDE_SKILL_DIR}/modules/context-budget.md` → 残コンテキスト評価

#### 4.8 Integration Hooks: on_phase_complete
有効なインテグレーションの `on_phase_complete` フックを発火。

#### 4.9 Regate チェック
modules に `regate` が含まれ、トリガーが検出された場合:
1. Integration Hooks: `on_regate` 発火
2. Read `${CLAUDE_SKILL_DIR}/modules/regate.md` → プロトコル実行
3. Read `$PIPELINE_DIR/regate/{strategy_file}` → 戦略適用
4. `rewind_to` フェーズから再実行

### 5. 完了処理

1. Integration Hooks: `on_pipeline_complete` 発火
2. Handover 生成
3. Knowledge Capture
