# Workflow Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** feature-dev / debug-flow のオーケストレーションロジックを workflow-engine 内部スキルとして抽出し、プラガブルなモジュールシステムで共通化する

**Architecture:** pipeline.yml (v2) をスキーマで定義し、workflow-engine が SSOT に基づいてフェーズディスパッチ・監査・regate・integration hooks を駆動する。パイプラインスキルは薄いエントリポイントに縮小。

**Tech Stack:** Markdown (SKILL.md, modules), YAML (pipeline.yml), JSON Schema (Draft 2020-12)

**Spec:** `docs/superpowers/specs/2026-04-04-workflow-engine-design.md`

---

### Task 1: JSON Schema の作成

**Files:**
- Create: `claude/skills/workflow-engine/schema/pipeline.v2.schema.json`

- [ ] **Step 1: ディレクトリ作成**

```bash
mkdir -p claude/skills/workflow-engine/schema
```

- [ ] **Step 2: JSON Schema ファイル作成**

設計書セクション 4.1 に定義されたスキーマ全文を `pipeline.v2.schema.json` として作成する。設計書の JSON をそのまま使用する。

- [ ] **Step 3: JSON 構文検証**

```bash
python3 -c "import json; json.load(open('claude/skills/workflow-engine/schema/pipeline.v2.schema.json'))" && echo "VALID JSON"
```

Expected: `VALID JSON`

- [ ] **Step 4: コミット**

```bash
git add claude/skills/workflow-engine/schema/pipeline.v2.schema.json
git commit -m "add pipeline.yml v2 JSON Schema (SSOT)"
```

---

### Task 2: モジュール作成 — 既存ファイル移動（audit, autonomy, inner-loop）

**Files:**
- Create: `claude/skills/workflow-engine/modules/audit.md`
- Create: `claude/skills/workflow-engine/modules/autonomy.md`
- Create: `claude/skills/workflow-engine/modules/inner-loop.md`
- Source: `claude/skills/feature-dev/references/audit-gate-protocol.md` (404行)
- Source: `claude/skills/feature-dev/references/autonomy-gates.md` (143行)
- Source: `claude/skills/feature-dev/references/inner-loop-protocol.md` (188行)

- [ ] **Step 1: modules ディレクトリ作成**

```bash
mkdir -p claude/skills/workflow-engine/modules
```

- [ ] **Step 2: audit.md 作成 — audit-gate-protocol.md を移動し、憲法的ルールを冒頭に追加**

`claude/skills/feature-dev/references/audit-gate-protocol.md` の内容をコピーし、フロントマターの name/description を調整する。さらに、ファイル冒頭（フロントマター直後、`# Audit Gate Protocol` の前）に以下の「憲法的ルール」セクションを挿入する:

```markdown
## 憲法的ルール（Constitutional Rules）

以下のルールはパイプライン実行において例外なく適用される。

- パイプラインのフェーズ遷移時、done-criteria に定義された監査ゲートは例外なく実行すること
- audit: required → phase-auditor エージェントを起動。省略・スキップ禁止
- audit: lite → エンジン自身が基準を直接検証。省略・スキップ禁止
- 監査未実行のフェーズ遷移は無効とみなす
- コンテキスト逼迫・時間的制約を理由にした監査スキップは認めない。逼迫時は handover を実行せよ
```

フロントマターの description を更新:
```yaml
---
name: audit-gate-protocol
description: >-
  workflow-engine 共通の Audit Gate プロトコル。Phase 完了後の監査フロー、
  Fix Dispatch 戦略、Re-gate + Re-review ループ、PAUSE 復帰の全手順を定義する。
  憲法的ルール（スキップ禁止）を含む。
---
```

- [ ] **Step 3: autonomy.md 作成 — autonomy-gates.md をコピー**

`claude/skills/feature-dev/references/autonomy-gates.md` の内容をそのまま `claude/skills/workflow-engine/modules/autonomy.md` にコピーする。フロントマターは変更不要（内容がそのまま適用可能）。

- [ ] **Step 4: inner-loop.md 作成 — inner-loop-protocol.md をコピー**

`claude/skills/feature-dev/references/inner-loop-protocol.md` の内容をそのまま `claude/skills/workflow-engine/modules/inner-loop.md` にコピーする。フロントマターは変更不要。

- [ ] **Step 5: ファイル存在確認**

```bash
wc -l claude/skills/workflow-engine/modules/audit.md claude/skills/workflow-engine/modules/autonomy.md claude/skills/workflow-engine/modules/inner-loop.md
```

Expected: audit.md ~415行（元404 + 憲法11行）、autonomy.md 143行、inner-loop.md 188行

- [ ] **Step 6: 憲法的ルールが audit.md の冒頭に存在することを確認**

```bash
head -20 claude/skills/workflow-engine/modules/audit.md
```

Expected: フロントマター直後に `## 憲法的ルール（Constitutional Rules）` が存在する

- [ ] **Step 7: コミット**

```bash
git add claude/skills/workflow-engine/modules/audit.md claude/skills/workflow-engine/modules/autonomy.md claude/skills/workflow-engine/modules/inner-loop.md
git commit -m "add modules: audit (with constitutional rules), autonomy, inner-loop"
```

---

### Task 3: モジュール作成 — SKILL.md から抽出（regate, phase-summary, context-budget, resume）

**Files:**
- Create: `claude/skills/workflow-engine/modules/regate.md`
- Create: `claude/skills/workflow-engine/modules/phase-summary.md`
- Create: `claude/skills/workflow-engine/modules/context-budget.md`
- Create: `claude/skills/workflow-engine/modules/resume.md`
- Source: `claude/skills/feature-dev/SKILL.md:114-121` (Regate ディスパッチ)
- Source: `claude/skills/feature-dev/SKILL.md:79-112` (Phase Summary 生成)
- Source: `claude/skills/feature-dev/SKILL.md:124-131` (Handover 判定)
- Source: `claude/skills/feature-dev/SKILL.md:33-47` (Resume Gate)

- [ ] **Step 1: regate.md 作成**

feature-dev/SKILL.md の「Regate ディスパッチ」セクション（行114-121）を抽出し、以下の構造で作成する:

```markdown
---
name: regate
description: >-
  Regate ディスパッチプロトコル。失敗トリガーの検出、戦略ファイルの適用、
  verification chain の再実行手順を定義する。
---

# Regate ディスパッチプロトコル

Regate は失敗発生時にパイプラインを巻き戻して再実行する仕組みである。

## 実行手順

1. `pipeline.yml` の `regate` セクションからトリガー種別を判定
2. `$PIPELINE_DIR/regate/{strategy_file}` を Read（該当戦略のみ、遅延ロード）
3. 元フェーズの findings / fail_reasons を Phase Summary から取得
4. fix_instruction を組み立て → rewind_to フェーズに注入
5. `verification_chain` を実行（各フェーズは通常のロード手順）
6. コード変更がない audit_failure → 現フェーズの re-audit のみ

## トリガー種別

pipeline.yml の regate セクションにトリガーごとの strategy を定義する。
トリガー名はパイプライン固有に自由定義可能（例: review_findings, test_failure, audit_failure, security_failure）。

各トリガーは以下を持つ:
- `strategy_file`: 戦略ファイルのパス（$PIPELINE_DIR からの相対パス）
- `rewind_to`: 巻き戻し先フェーズ ID（`current` で現フェーズのみ再監査）
- `max_retries`: 最大リトライ回数（省略時は settings.max_phase_retries）
```

- [ ] **Step 2: phase-summary.md 作成**

feature-dev/SKILL.md の「Phase Summary 生成」セクション（行79-112）を抽出し、以下の構造で作成する:

```markdown
---
name: phase-summary
description: >-
  Phase Summary の生成フォーマットとアーティファクト追跡ルール。
  各フェーズ完了時に構造化サマリーを生成し保存する。
---

# Phase Summary 生成プロトコル

各フェーズ完了時にオーケストレーターが生成する構造化サマリー。

## 保存先

`.claude/handover/{branch}/{fingerprint}/phase-summaries/{phase_id}.yml`

## フォーマット

```yaml
phase_id: <phase_id>
phase_name: <name>
status: completed | failed
timestamp: <ISO8601>
attempt: <N>
audit_verdict: PASS | FAIL

artifacts:
  <name>:
    type: file | git_range | inline
    value: <参照先>

decisions: []
concerns:
  - target_phase: <phase_id>
    content: <内容>
directives:
  - target_phase: <phase_id>
    content: <内容>

evidence:
  - type: <種別>
    content: <内容> | local_path: <パス>
    linear_sync: inline | attached | reference_only

regate_history: []
```

## アーティファクト型

| type | 解決方法 | 用途 |
|------|---------|------|
| `file` | Read で読み込み | 設計書、計画書、レポート |
| `git_range` | git diff で参照 | コード変更 |
| `inline` | そのまま使用 | 短いテスト結果、メトリクス |

## concerns/directives 伝播ルール

- 各フェーズは concerns と directives を emit できる
- 両者は `target_phase` で送信先を指定
- エンジンは受信フェーズ進入時に `target_phase` でフィルタし注入する
```

- [ ] **Step 3: context-budget.md 作成**

feature-dev/SKILL.md の「Handover 判定」セクション（行124-131）を抽出する:

```markdown
---
name: context-budget
description: >-
  コンテキスト予算管理と handover 判定プロトコル。
  残コンテキストと pipeline.yml の設定に基づき handover の要否を判定する。
---

# コンテキスト予算管理プロトコル

フェーズ完了・Phase Summary 生成後に handover の要否を判定する。

## 判定ロジック

1. pipeline.yml phases 内の当該フェーズの `handover` ポリシーを参照
   - 未指定の場合は `settings.default_handover` を使用
2. ポリシーに基づき判定:
   - `always` → 無条件で `/handover` 実行
   - `optional` → `settings.context_budget` と残コンテキストを比較
     - 次フェーズの phase + references 予算が残コンテキストに収まらない場合 → handover
   - `never` → 続行
     - ただし残量が critical 閾値（orchestrator 予算の 50%）を下回った場合は例外的に handover

## context_budget の参照

pipeline.yml の `settings.context_budget` で定義:
- `orchestrator`: SKILL.md + pipeline.yml 用
- `phase`: phases/*.md + done-criteria 用
- `references`: references/*.md + modules 用
```

- [ ] **Step 4: resume.md 作成**

feature-dev/SKILL.md の「Resume Gate」セクション（行33-47）を抽出する:

```markdown
---
name: resume
description: >-
  Resume Gate プロトコル。handover state からのパイプライン復帰フローを定義する。
---

# Resume Gate プロトコル

パイプライン起動時の最優先評価。handover state が存在すれば復帰、なければ新規開始。

## 実行手順

1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
2. `pipeline` フィールドが現パイプライン名と一致するか確認
3. 一致 → **Resume Mode**:
   - `pipeline.yml` を Read
   - `phase_summaries` から `current_phase` を特定（最初の未完了フェーズ）
   - `current_phase` の Phase Summary から concerns/directives を抽出（target_phase でフィルタ）
   - ユーザー承認を得て `current_phase` から再開
4. 不一致 or 不在 → **New Mode**:
   - pipeline.yml の最初のフェーズから開始
```

- [ ] **Step 5: 全モジュールファイルの存在確認**

```bash
ls -la claude/skills/workflow-engine/modules/
```

Expected: audit.md, autonomy.md, context-budget.md, inner-loop.md, phase-summary.md, regate.md, resume.md（計7ファイル）

- [ ] **Step 6: コミット**

```bash
git add claude/skills/workflow-engine/modules/regate.md claude/skills/workflow-engine/modules/phase-summary.md claude/skills/workflow-engine/modules/context-budget.md claude/skills/workflow-engine/modules/resume.md
git commit -m "add modules: regate, phase-summary, context-budget, resume"
```

---

### Task 4: workflow-engine/SKILL.md の作成

**Files:**
- Create: `claude/skills/workflow-engine/SKILL.md`

- [ ] **Step 1: SKILL.md 作成**

設計書セクション 2 の仕様に基づいて作成する。以下の構造:

```markdown
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
2. `version` フィールドを確認 → 2 以外なら PAUSE してユーザーに通知
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
3. `requires_artifacts` を Phase Summary チェーンから解決:
   - `type: file` → Read
   - `type: git_range` → git diff で参照
   - `type: inline` → そのまま使用
4. 前フェーズの concerns/directives を `target_phase` でフィルタし注入
5. `phase_references` を Read（`$PIPELINE_DIR/references/` 内）

#### 4.4 Phase 実行
phase.md の指示に従いフェーズを実行する。

#### 4.5 Audit Gate
modules に `audit` が含まれ、かつ `done_criteria` が定義されている場合:
1. Read `${CLAUDE_SKILL_DIR}/modules/audit.md` → プロトコル実行
2. Read `$PIPELINE_DIR/{phase.done_criteria}`
3. `audit: required` → phase-auditor エージェント起動
4. `audit: lite` → エンジン自身が基準を直接検証
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
```

- [ ] **Step 2: フロントマターの user-invocable: false が正しいことを確認**

```bash
head -6 claude/skills/workflow-engine/SKILL.md
```

Expected: `user-invocable: false` が含まれる

- [ ] **Step 3: コミット**

```bash
git add claude/skills/workflow-engine/SKILL.md
git commit -m "add workflow-engine SKILL.md orchestration engine"
```

---

### Task 5: feature-dev/pipeline.yml の更新

**Files:**
- Modify: `claude/skills/feature-dev/pipeline.yml`

- [ ] **Step 1: pipeline.yml を v2 に更新**

設計書セクション 4.4 の完全な pipeline.yml で上書きする。変更点:
- `version: 1` → `version: 2`
- `modules` セクション追加
- `integrations` セクション追加（linear-sync）
- execute フェーズに `uses: [inner-loop]` 追加
- `settings.linear_sync: auto` 削除
- 冗長な `skip: false` を持つフェーズから除去（integrate は `handover: never` のため残す）
- 先頭に yaml-language-server schema コメント追加:
  ```yaml
  # yaml-language-server: $schema=../../workflow-engine/schema/pipeline.v2.schema.json
  ```

- [ ] **Step 2: YAML 構文検証**

```bash
python3 -c "import yaml; yaml.safe_load(open('claude/skills/feature-dev/pipeline.yml'))" && echo "VALID YAML"
```

Expected: `VALID YAML`

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/pipeline.yml
git commit -m "update feature-dev pipeline.yml to v2 with modules and integrations"
```

---

### Task 6: debug-flow/pipeline.yml の更新

**Files:**
- Modify: `claude/skills/debug-flow/pipeline.yml`

- [ ] **Step 1: pipeline.yml を v2 に更新**

設計書セクション 4.5 の完全な pipeline.yml で上書きする。変更点は Task 5 と同様。

先頭に schema コメント追加:
```yaml
# yaml-language-server: $schema=../../workflow-engine/schema/pipeline.v2.schema.json
```

- [ ] **Step 2: YAML 構文検証**

```bash
python3 -c "import yaml; yaml.safe_load(open('claude/skills/debug-flow/pipeline.yml'))" && echo "VALID YAML"
```

Expected: `VALID YAML`

- [ ] **Step 3: コミット**

```bash
git add claude/skills/debug-flow/pipeline.yml
git commit -m "update debug-flow pipeline.yml to v2 with modules and integrations"
```

---

### Task 7: feature-dev/SKILL.md の書き換え（薄いラッパー化）

**Files:**
- Modify: `claude/skills/feature-dev/SKILL.md`

- [ ] **Step 1: SKILL.md を薄いラッパーに書き換え**

現在の 138行から ~60行に縮小する。フロントマターは維持し、本文をフラグ定義 + workflow-engine invoke に置き換える:

```markdown
---
name: feature-dev
description: >-
  品質ゲート付き開発オーケストレーター。9フェーズで設計→レビュー→計画→レビュー→
  実装→Acceptanceテスト→ドキュメント監査→レビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Review フェーズで test-review 観点を有効化。
  --accept 指定時は accept-test フェーズを有効化。
  --doc 指定時は doc-audit フェーズを有効化。
disable-model-invocation: true
user-invocable: true
---

# feature-dev Pipeline

品質ゲート付き9フェーズ開発パイプライン。workflow-engine で駆動される。

## 引数パース

$ARGUMENTS からフラグを抽出:
- `--codex`: 全レビューフェーズで Codex 並列レビュー有効化
- `--e2e`: Review フェーズで test-review 観点を有効化
- `--accept`: accept-test フェーズを有効化
- `--doc`: doc-audit フェーズを有効化
- `--ui`: Review フェーズに UI レビューエージェントを追加
- `--iterations N`: レビューフェーズの N-way 投票回数（デフォルト: 3）
- `--swarm`: 対応フェーズでエージェントチーム化
- `--linear`: Linear インテグレーションを有効化（pipeline.yml の integrations で定義）
- 残りのテキスト: タスク説明

## 実行

1. 上記フラグを JSON にパース: `{"codex": false, "e2e": false, "accept": false, "doc": false, "ui": false, "iterations": 3, "swarm": false, "linear": false}`
2. workflow-engine を invoke:
   ```
   Skill("workflow-engine", "${CLAUDE_SKILL_DIR} {flags_json} {task_description}")
   ```
3. 以降のオーケストレーション（Resume Gate、Phase Dispatch、Audit Gate、Regate、Handover、Integration Hooks）は全て workflow-engine が駆動する。
```

- [ ] **Step 2: 行数が大幅に削減されていることを確認**

```bash
wc -l claude/skills/feature-dev/SKILL.md
```

Expected: ~45-60行（元138行）

- [ ] **Step 3: コミット**

```bash
git add claude/skills/feature-dev/SKILL.md
git commit -m "rewrite feature-dev SKILL.md as thin wrapper for workflow-engine"
```

---

### Task 8: debug-flow/SKILL.md の書き換え（薄いラッパー化）

**Files:**
- Modify: `claude/skills/debug-flow/SKILL.md`

- [ ] **Step 1: SKILL.md を薄いラッパーに書き換え**

feature-dev と同構造。差異は以下のみ:
- name: `debug-flow`
- description: 「品質ゲート付きデバッグオーケストレーター。8フェーズで根本原因分析→修正計画→レビュー→実装→...」
- タイトル: `# debug-flow Pipeline`
- 説明: 「品質ゲート付き8フェーズデバッグパイプライン」
- 残りのテキスト説明: 「バグ報告/症状」

```markdown
---
name: debug-flow
description: >-
  品質ゲート付きデバッグオーケストレーター。8フェーズで根本原因分析→修正計画→レビュー→
  実装→Acceptanceテスト→ドキュメント監査→レビュー→統合を品質ゲート付きで実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Review フェーズで test-review 観点を有効化。
  --accept 指定時は accept-test フェーズを有効化。
  --doc 指定時は doc-audit フェーズを有効化。
disable-model-invocation: true
user-invocable: true
---

# debug-flow Pipeline

品質ゲート付き8フェーズデバッグパイプライン。workflow-engine で駆動される。

## 引数パース

$ARGUMENTS からフラグを抽出:
- `--codex`: 全レビューフェーズで Codex 並列レビュー有効化
- `--e2e`: Review フェーズで test-review 観点を有効化
- `--accept`: accept-test フェーズを有効化
- `--doc`: doc-audit フェーズを有効化
- `--ui`: Review フェーズに UI レビューエージェントを追加
- `--iterations N`: レビューフェーズの N-way 投票回数（デフォルト: 3）
- `--swarm`: 対応フェーズでエージェントチーム化
- `--linear`: Linear インテグレーションを有効化（pipeline.yml の integrations で定義）
- 残りのテキスト: バグ報告/症状

## 実行

1. 上記フラグを JSON にパース: `{"codex": false, "e2e": false, "accept": false, "doc": false, "ui": false, "iterations": 3, "swarm": false, "linear": false}`
2. workflow-engine を invoke:
   ```
   Skill("workflow-engine", "${CLAUDE_SKILL_DIR} {flags_json} {task_description}")
   ```
3. 以降のオーケストレーション（Resume Gate、Phase Dispatch、Audit Gate、Regate、Handover、Integration Hooks）は全て workflow-engine が駆動する。
```

- [ ] **Step 2: 行数確認**

```bash
wc -l claude/skills/debug-flow/SKILL.md
```

Expected: ~45-60行（元138行）

- [ ] **Step 3: コミット**

```bash
git add claude/skills/debug-flow/SKILL.md
git commit -m "rewrite debug-flow SKILL.md as thin wrapper for workflow-engine"
```

---

### Task 9: phases/execute.md フロントマター更新

**Files:**
- Modify: `claude/skills/feature-dev/phases/execute.md:1-14`
- Modify: `claude/skills/debug-flow/phases/execute.md:1-14`

- [ ] **Step 1: feature-dev/phases/execute.md のフロントマター更新**

`phase_references` から `references/inner-loop-protocol.md` を削除する。`references/audit-gate-protocol.md` も削除する（modules/audit.md は engine が Audit Gate 時に注入するため）。

変更前:
```yaml
phase_references:
  - references/audit-gate-protocol.md
  - references/inner-loop-protocol.md
```

変更後:
```yaml
phase_references: []
```

- [ ] **Step 2: debug-flow/phases/execute.md のフロントマター更新**

同じ変更を適用する。

変更前:
```yaml
phase_references:
  - references/audit-gate-protocol.md
  - references/inner-loop-protocol.md
```

変更後:
```yaml
phase_references: []
```

- [ ] **Step 3: 変更内容の確認**

```bash
head -14 claude/skills/feature-dev/phases/execute.md && echo "---" && head -14 claude/skills/debug-flow/phases/execute.md
```

Expected: 両方の `phase_references` が `[]` になっている

- [ ] **Step 4: コミット**

```bash
git add claude/skills/feature-dev/phases/execute.md claude/skills/debug-flow/phases/execute.md
git commit -m "remove stale phase_references from execute.md (now injected by engine)"
```

---

### Task 10: 旧ファイル削除 + symlink 解消

**Files:**
- Delete: `claude/skills/feature-dev/references/audit-gate-protocol.md`
- Delete: `claude/skills/feature-dev/references/autonomy-gates.md`
- Delete: `claude/skills/feature-dev/references/inner-loop-protocol.md`
- Delete: `claude/skills/debug-flow/references/audit-gate-protocol.md` (symlink)
- Delete: `claude/skills/debug-flow/references/autonomy-gates.md` (symlink)
- Delete: `claude/skills/debug-flow/references/inner-loop-protocol.md`
- Delete: `claude/skills/debug-flow/references/` (directory)

- [ ] **Step 1: symlink が本当に symlink であることを確認**

```bash
file claude/skills/debug-flow/references/audit-gate-protocol.md claude/skills/debug-flow/references/autonomy-gates.md
```

Expected: 両方とも `symbolic link to` と表示される

- [ ] **Step 2: debug-flow の references/ を削除**

```bash
rm claude/skills/debug-flow/references/audit-gate-protocol.md
rm claude/skills/debug-flow/references/autonomy-gates.md
rm claude/skills/debug-flow/references/inner-loop-protocol.md
rmdir claude/skills/debug-flow/references
```

- [ ] **Step 3: feature-dev の移動済み references を削除**

```bash
rm claude/skills/feature-dev/references/audit-gate-protocol.md
rm claude/skills/feature-dev/references/autonomy-gates.md
rm claude/skills/feature-dev/references/inner-loop-protocol.md
```

- [ ] **Step 4: brainstorming-supplement.md が残っていることを確認**

```bash
ls claude/skills/feature-dev/references/
```

Expected: `brainstorming-supplement.md` のみ

- [ ] **Step 5: debug-flow/references/ が存在しないことを確認**

```bash
ls claude/skills/debug-flow/references/ 2>&1
```

Expected: `No such file or directory`

- [ ] **Step 6: コミット**

```bash
git add -A claude/skills/feature-dev/references/ claude/skills/debug-flow/references/
git commit -m "remove old reference files and symlinks (moved to workflow-engine/modules/)"
```

---

### Task 11: CLAUDE.md の Audit Gate セクション削除

**Files:**
- Modify: `claude/CLAUDE.md:16-22`

- [ ] **Step 1: Audit Gate セクションを削除**

以下のセクション（行16-22）を丸ごと削除する:

```markdown
## Audit Gate（憲法）

- /feature-dev, /debug-flow のフェーズ遷移時、done-criteria に定義された監査ゲートは例外なく実行すること
- audit: required → phase-auditor エージェントを起動。省略・スキップ禁止
- audit: lite → オーケストレーターが基準を直接検証。省略・スキップ禁止
- 監査未実行のフェーズ遷移は無効とみなす
- コンテキスト逼迫・時間的制約を理由にした監査スキップは認めない。逼迫時は handover を実行せよ
```

- [ ] **Step 2: Audit Gate が CLAUDE.md に残っていないことを確認**

```bash
grep -n "Audit Gate" claude/CLAUDE.md
```

Expected: 出力なし

- [ ] **Step 3: 他のセクションが正しく残っていることを確認**

```bash
grep "^## " claude/CLAUDE.md
```

Expected: コミュニケーション方針, 出力方針, 実装規律, Knowledge Capture, マルチエージェント, Verification Contract, Intent Guard, セッション管理, 実装前検証, フォーマッタ・リンタのスコープ, Document Dependency Check（Audit Gate なし）

- [ ] **Step 4: コミット**

```bash
git add claude/CLAUDE.md
git commit -m "move Audit Gate rules from CLAUDE.md to workflow-engine/modules/audit.md"
```

---

### Task 12: 最終検証

**Files:** なし（検証のみ）

- [ ] **Step 1: workflow-engine ディレクトリ構造の確認**

```bash
find claude/skills/workflow-engine -type f | sort
```

Expected:
```
claude/skills/workflow-engine/SKILL.md
claude/skills/workflow-engine/modules/audit.md
claude/skills/workflow-engine/modules/autonomy.md
claude/skills/workflow-engine/modules/context-budget.md
claude/skills/workflow-engine/modules/inner-loop.md
claude/skills/workflow-engine/modules/phase-summary.md
claude/skills/workflow-engine/modules/regate.md
claude/skills/workflow-engine/modules/resume.md
claude/skills/workflow-engine/schema/pipeline.v2.schema.json
```

- [ ] **Step 2: symlink が一切残っていないことを確認**

```bash
find claude/skills/feature-dev claude/skills/debug-flow -type l
```

Expected: 出力なし（symlink ゼロ）

- [ ] **Step 3: pipeline.yml が v2 であることを確認**

```bash
head -3 claude/skills/feature-dev/pipeline.yml && echo "---" && head -3 claude/skills/debug-flow/pipeline.yml
```

Expected: 両方とも `version: 2` を含む

- [ ] **Step 4: SKILL.md が薄いラッパーであることを確認**

```bash
wc -l claude/skills/feature-dev/SKILL.md claude/skills/debug-flow/SKILL.md
```

Expected: 各 45-60行程度

- [ ] **Step 5: 憲法的ルールの移動を確認**

```bash
grep -c "Constitutional Rules" claude/skills/workflow-engine/modules/audit.md && grep -c "Audit Gate" claude/CLAUDE.md
```

Expected: `1` と `0`（audit.md に存在し、CLAUDE.md には不在）

- [ ] **Step 6: JSON Schema の構文再確認**

```bash
python3 -c "import json; s = json.load(open('claude/skills/workflow-engine/schema/pipeline.v2.schema.json')); print(f'Schema OK: {s[\"title\"]}')"
```

Expected: `Schema OK: Workflow Engine Pipeline Definition`

- [ ] **Step 7: feature-dev/references/ に brainstorming-supplement.md のみ残存**

```bash
ls claude/skills/feature-dev/references/
```

Expected: `brainstorming-supplement.md` のみ
