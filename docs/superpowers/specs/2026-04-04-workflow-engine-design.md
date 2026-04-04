# Workflow Engine — 設計書

## 概要

feature-dev / debug-flow のオーケストレーションロジックを `workflow-engine` 内部スキルとして抽出し、パイプライン型ワークフローの共通エンジンとする。監査プロトコル・regate・inner-loop 等の知識はエンジン内のモジュールとして配置し、pipeline.yml の宣言で注入する。

### 動機

1. **DRY**: feature-dev / debug-flow の SKILL.md は 139行中 132行が完全同一。オーケストレーションの一元化で重複を排除する
2. **シンボリックリンク排除**: debug-flow が feature-dev の references/ を symlink で参照する構造は管理上の技術的負債。モジュール化で解消する
3. **拡張性**: 新パイプライン作成を pipeline.yml + phases/ + done-criteria/ の定義だけで完結させる
4. **プラガブル設計**: モジュール（audit, inner-loop 等）を DI 的に注入可能にし、パイプラインごとに必要な知識だけを組み合わせられるようにする
5. **関心の分離**: CLAUDE.md からワークフロー固有のルール（Audit Gate 憲法）を分離し、CLAUDE.md をスリム化する

### 対象

- workflow-engine（新規作成）
- feature-dev（SKILL.md 書き換え、references/ 整理）
- debug-flow（SKILL.md 書き換え、symlink 削除、references/ 削除）
- CLAUDE.md（Audit Gate セクション移動）

### 対象外

- レビュースキル群（code-review, spec-review 等）: 現状維持
- 軽量ワークフロー（triage, linear-refresh 等）: 現状維持
- linear-sync, handover, continue: 独立スキルとして現状維持
- phases/, done-criteria/, regate/ の内容ファイル: 変更なし

---

## 1. ディレクトリ構成

### 改定後

```
skills/
├── workflow-engine/                         # user-invocable: false（内部スキル）
│   ├── SKILL.md                             # オーケストレーションエンジン本体
│   └── modules/
│       ├── audit.md                         # Audit Gate プロトコル + Fix Dispatch
│       ├── autonomy.md                      # Autonomy Gates（自律判断の境界）
│       ├── regate.md                        # Regate ディスパッチプロトコル
│       ├── phase-summary.md                 # Phase Summary フォーマット + アーティファクト追跡
│       ├── context-budget.md                # コンテキスト予算管理 + handover 判定
│       ├── resume.md                        # Resume Gate プロトコル
│       └── inner-loop.md                    # Execute フェーズ inner loop (TDD + TestEnrich + Verify)
│
├── feature-dev/
│   ├── SKILL.md                             # 薄いエントリポイント（フラグ定義 + engine invoke）
│   ├── pipeline.yml                         # modules 宣言追加
│   ├── phases/                              # 9ファイル（変更なし）
│   ├── done-criteria/                       # 9ファイル（変更なし）
│   ├── regate/                              # 3ファイル（変更なし）
│   └── references/
│       └── brainstorming-supplement.md      # feature-dev 固有（残存）
│       # audit-gate-protocol.md    → 削除（modules/audit.md へ）
│       # autonomy-gates.md         → 削除（modules/autonomy.md へ）
│       # inner-loop-protocol.md    → 削除（modules/inner-loop.md へ）
│
├── debug-flow/
│   ├── SKILL.md                             # 薄いエントリポイント
│   ├── pipeline.yml                         # modules 宣言追加
│   ├── phases/                              # 8ファイル（変更なし）
│   ├── done-criteria/                       # 8ファイル（変更なし）
│   ├── regate/                              # 3ファイル（変更なし）
│   └── # references/ ディレクトリ削除
│       # audit-gate-protocol.md    → 削除（symlink、modules/audit.md へ）
│       # autonomy-gates.md         → 削除（symlink、modules/autonomy.md へ）
│       # inner-loop-protocol.md    → 削除（modules/inner-loop.md へ）
│
├── linear-sync/                             # 変更なし
├── continue/                                # 変更なし
├── handover/                                # 変更なし
└── ...
```

### 削除されるファイル

| ファイル | 理由 |
|---------|------|
| `feature-dev/references/audit-gate-protocol.md` | `workflow-engine/modules/audit.md` に移動 |
| `feature-dev/references/autonomy-gates.md` | `workflow-engine/modules/autonomy.md` に移動 |
| `feature-dev/references/inner-loop-protocol.md` | `workflow-engine/modules/inner-loop.md` に移動 |
| `debug-flow/references/audit-gate-protocol.md` | symlink → 削除 |
| `debug-flow/references/autonomy-gates.md` | symlink → 削除 |
| `debug-flow/references/inner-loop-protocol.md` | 完全同一 → 削除 |
| `debug-flow/references/` | ディレクトリごと削除（中身が空になるため）|

---

## 2. workflow-engine/SKILL.md 仕様

### フロントマター

```yaml
---
name: workflow-engine
description: >-
  パイプライン型ワークフローの汎用オーケストレーションエンジン。
  Phase Dispatch, Audit Gate, Regate, Handover, Linear Sync を駆動する。
  feature-dev, debug-flow 等のパイプラインスキルから呼び出される。
user-invocable: false
---
```

### 引数

| 位置 | 内容 | 例 |
|-----|------|-----|
| `$ARGUMENTS[0]` | パイプラインスキルのディレクトリパス | `/path/to/skills/feature-dev` |
| `$ARGUMENTS[1]` | パースされたフラグ（JSON） | `{"linear":true,"accept":true,"codex":false,...}` |
| `$ARGUMENTS[2]` | タスク記述 | `"ユーザー認証機能の追加"` |

### オーケストレーションループ

```
1. 初期化
   ├── Read $PIPELINE_DIR/pipeline.yml
   ├── modules 宣言を解析 → 使用モジュールを特定
   ├── pipeline.yml の pipeline フィールドからパイプライン名を取得
   └── フラグ展開

2. Resume Gate
   └── modules に resume が含まれる場合:
       Read ${CLAUDE_SKILL_DIR}/modules/resume.md → プロトコル実行
       handover state があれば復帰、なければ New Mode

3. Phase Dispatch Loop
   for each phase in pipeline.yml.phases:
   │
   ├── Skip 評価
   │   ├── skip: true → スキップ
   │   └── skip_unless: <flag> → フラグ未指定ならスキップ
   │
   ├── Phase 実行準備
   │   ├── Read $PIPELINE_DIR/phases/{phase.id}.md
   │   ├── uses モジュール注入: phase に uses 宣言があれば
   │   │   該当 ${CLAUDE_SKILL_DIR}/modules/{module}.md を Read し注入
   │   ├── requires_artifacts を Phase Summary チェーンから解決
   │   │   ├── type: file → Read
   │   │   ├── type: git_range → git diff で参照
   │   │   └── type: inline → そのまま使用
   │   ├── concerns/directives を target_phase でフィルタし注入
   │   └── phase_references を Read（$PIPELINE_DIR/references/ 内）
   │
   ├── Phase 実行（phase.md の指示に従う）
   │
   ├── Audit Gate（modules に audit が含まれ、かつ done_criteria が定義されている場合）
   │   ├── Read ${CLAUDE_SKILL_DIR}/modules/audit.md → プロトコル実行
   │   ├── Read $PIPELINE_DIR/done-criteria/{phase.id}.md
   │   ├── audit: required → phase-auditor エージェント起動
   │   ├── audit: lite → エンジン自身が検証
   │   └── FAIL → Fix Dispatch → Re-audit（max_retries まで）
   │
   ├── Phase Summary 生成
   │   └── Read ${CLAUDE_SKILL_DIR}/modules/phase-summary.md → フォーマットに従い生成
   │
   ├── Handover 判定
   │   └── Read ${CLAUDE_SKILL_DIR}/modules/context-budget.md → 残コンテキスト評価
   │
   ├── Linear Sync（フラグ有効時）
   │   └── Skill("linear-sync") を invoke
   │
   └── Regate チェック（modules に regate が含まれ、トリガー検出時）
       └── Read ${CLAUDE_SKILL_DIR}/modules/regate.md → プロトコル実行
       └── Read $PIPELINE_DIR/regate/{strategy}.md → 戦略適用
       └── rewind_to フェーズから再実行

4. 完了処理
   └── Handover 生成 / Linear Sync 完了 / Knowledge Capture
```

### パス解決ルール

エンジンは2つのベースパスを使い分ける:

| パス | 解決先 | 用途 |
|-----|-------|------|
| `${CLAUDE_SKILL_DIR}` | `workflow-engine/` | modules/*.md の読み込み |
| `$PIPELINE_DIR` | `$ARGUMENTS[0]`（例: `feature-dev/`） | pipeline.yml, phases/, done-criteria/, regate/, references/ の読み込み |

---

## 3. モジュール仕様

### 3.1 注入の仕組み

モジュールは2つのレベルで注入される:

**エンジンレベルモジュール** — pipeline.yml の `modules` 宣言で有効化。オーケストレーションループの該当ステップで読み込まれる。

```yaml
# pipeline.yml
modules:
  - audit
  - regate
  - resume
  - phase-summary
  - context-budget
  - autonomy
```

**フェーズレベルモジュール** — pipeline.yml のフェーズ定義内の `uses` 宣言で有効化。該当フェーズの実行準備時に読み込まれる。

```yaml
# pipeline.yml
phases:
  - id: execute
    phase_file: phases/execute.md
    done_criteria: done-criteria/execute.md
    uses: [inner-loop]    # エンジンがフェーズ実行前にモジュールを注入
    produces: [code_changes, test_results, evidence_collection]
```

### 3.2 モジュール一覧

| モジュール | レベル | 行数(推定) | 移動元 | 内容 |
|-----------|-------|-----------|-------|------|
| `audit.md` | エンジン | ~400行 | feature-dev/references/audit-gate-protocol.md + CLAUDE.md Audit Gate セクション | Audit Gate 実行フロー、Fix Dispatch テーブル、Audit Context テンプレート、Re-gate + Re-review ループ、PAUSE 復帰、Swarm Team プロトコル、**憲法的ルール** |
| `autonomy.md` | エンジン | ~140行 | feature-dev/references/autonomy-gates.md | 自律判断の境界定義、ユーザー確認が必要なタイミング |
| `regate.md` | エンジン | ~60行 | feature-dev/debug-flow SKILL.md 内 Regate セクション | Regate ディスパッチプロトコル、verification chain 実行手順、戦略ファイル適用フロー（戦略ファイル自体は各パイプラインの regate/ に残る） |
| `phase-summary.md` | エンジン | ~50行 | feature-dev/debug-flow SKILL.md 内 Phase Summary セクション | Summary YAML フォーマット定義、アーティファクト型（file/git_range/inline）、concerns/directives 伝播ルール |
| `context-budget.md` | エンジン | ~30行 | pipeline.yml settings + SKILL.md Handover セクション | コンテキスト残量評価、handover トリガー閾値、handover policy（always/optional/never）評価 |
| `resume.md` | エンジン | ~40行 | feature-dev/debug-flow SKILL.md 内 Resume Gate セクション | handover state 検出、phase_summaries からの復帰フロー、ユーザー承認 |
| `inner-loop.md` | フェーズ | ~190行 | feature-dev/references/inner-loop-protocol.md（debug-flow と完全同一） | Impl(TDD) → TestEnrich → Verify サイクル、テスト階層（Unit/Integration/Acceptance）、Failure Router、ループ制御（max 3 iterations） |

### 3.3 audit.md への憲法的ルール統合

CLAUDE.md から移動する「Audit Gate（憲法）」セクションは、audit.md の**冒頭**に配置する:

```markdown
## 憲法的ルール（Constitutional Rules）

以下のルールはパイプライン実行において例外なく適用される。

- パイプラインのフェーズ遷移時、done-criteria に定義された監査ゲートは例外なく実行すること
- audit: required → phase-auditor エージェントを起動。省略・スキップ禁止
- audit: lite → エンジン自身が基準を直接検証。省略・スキップ禁止
- 監査未実行のフェーズ遷移は無効とみなす
- コンテキスト逼迫・時間的制約を理由にした監査スキップは認めない。逼迫時は handover を実行せよ
```

---

## 4. pipeline.yml の拡張

### 追加フィールド

| フィールド | レベル | 説明 |
|-----------|-------|------|
| `modules` | トップレベル | エンジンレベルモジュールのリスト |
| `uses` | フェーズ定義内 | フェーズレベルモジュールのリスト |

### feature-dev/pipeline.yml（改定後）

```yaml
pipeline: feature-dev
version: 2

modules:
  - audit
  - autonomy
  - regate
  - resume
  - phase-summary
  - context-budget

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
    uses: [inner-loop]
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
  linear_sync: auto
  context_budget:
    orchestrator: 150
    phase: 100
    references: 200
```

### debug-flow/pipeline.yml（改定後）

```yaml
pipeline: debug-flow
version: 2

modules:
  - audit
  - autonomy
  - regate
  - resume
  - phase-summary
  - context-budget

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
    uses: [inner-loop]
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
  linear_sync: auto
  context_budget:
    orchestrator: 150
    phase: 100
    references: 200
```

---

## 5. パイプラインスキルの改定

### feature-dev/SKILL.md（改定後）

```yaml
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
```

**SKILL.md 本文の責務:**

1. フラグ定義と解説
2. `$ARGUMENTS` のパース → フラグ JSON 構築
3. `workflow-engine` の呼び出し:
   ```
   Skill("workflow-engine", "${CLAUDE_SKILL_DIR} {flags_json} {task_description}")
   ```

フラグ一覧はパイプライン固有のため SKILL.md に残す:
- `--codex`: 全レビューフェーズで Codex 並列レビュー有効化
- `--e2e`: Review フェーズで test-review 観点を有効化
- `--accept`: accept-test フェーズを有効化
- `--doc`: doc-audit フェーズを有効化
- `--ui`: Review フェーズに UI レビューエージェントを追加
- `--iterations N`: レビューフェーズの N-way 投票回数（デフォルト: 3）
- `--swarm`: 対応フェーズでエージェントチーム化
- `--linear`: Linear チケットへの進捗同期を有効化
- 残りのテキスト: タスク説明

### debug-flow/SKILL.md（改定後）

同構造。フラグ定義は feature-dev と共通（残りのテキストの説明が「バグ報告/症状」になる点のみ異なる）。

---

## 6. CLAUDE.md の改定

### 削除するセクション

```markdown
## Audit Gate（憲法）

- /feature-dev, /debug-flow のフェーズ遷移時、done-criteria に定義された監査ゲートは例外なく実行すること
- audit: required → phase-auditor エージェントを起動。省略・スキップ禁止
- audit: lite → オーケストレーターが基準を直接検証。省略・スキップ禁止
- 監査未実行のフェーズ遷移は無効とみなす
- コンテキスト逼迫・時間的制約を理由にした監査スキップは認めない。逼迫時は handover を実行せよ
```

### 移動先

`workflow-engine/modules/audit.md` の冒頭「憲法的ルール」セクション。

### CLAUDE.md に残るセクション

- コミュニケーション方針
- 出力方針
- 実装規律
- Knowledge Capture
- マルチエージェント
- Verification Contract
- Intent Guard
- セッション管理
- 実装前検証
- フォーマッタ・リンタのスコープ
- Document Dependency Check

---

## 7. コンテキストウィンドウ影響分析

### 起動時のコンテキスト消費

| | 現状 | 改定後 |
|---|---|---|
| パイプライン SKILL.md | ~139行 | ~60行 |
| workflow-engine SKILL.md | — | ~200行 |
| pipeline.yml | ~98行 | ~105行（modules 追加分） |
| **起動時合計** | **~237行** | **~365行** |
| **差分** | | **+128行** |

### フェーズ実行時の追加ロード

| | 現状 | 改定後 |
|---|---|---|
| phases/{phase}.md | ~50-150行 | ~50-150行（変更なし） |
| done-criteria/{phase}.md | ~30-80行 | ~30-80行（変更なし） |
| modules/audit.md | — | ~400行（Audit Gate 時のみ） |
| modules/inner-loop.md | — | ~190行（Execute uses 時のみ） |
| references/audit-gate-protocol.md | ~404行 | — （audit.md に統合） |
| references/inner-loop-protocol.md | ~188行 | — （inner-loop.md に統合） |

### 総合評価

- **起動時**: +128行。CLAUDE.md の Audit Gate セクション削除（-6行）を加味しても増加。ただし workflow-engine は全パイプラインで共有されるため、debug-flow で同量の重複が消える
- **フェーズ実行時**: audit.md と audit-gate-protocol.md は同一内容（移動のみ）、inner-loop も同様。実質的なコンテキスト増減なし
- **モジュール on-demand 性**: audit.md (400行) は Audit Gate 到達まで読まれない。regate.md (60行) は regate トリガーまで読まれない。inner-loop.md (190行) は Execute フェーズのみ。順調なフェーズ通過時のピーク消費は現状と同等
- **CLAUDE.md 常時コスト**: -6行（Audit Gate セクション削除）。全会話で恩恵あり

---

## 8. パイプライン契約（Pipeline Contract）

workflow-engine を利用する新規パイプラインが満たすべき要件。

### 必須

| ファイル | 説明 |
|---------|------|
| `SKILL.md` | エントリポイント。フラグ定義 + workflow-engine の invoke |
| `pipeline.yml` | パイプライン定義。`pipeline`, `version`, `modules`, `phases`, `settings` |
| `phases/*.md` | 各フェーズの実行指示。フロントマターに `requires_artifacts`, `phase_references`, `invoke_agents`, `phase_flags` |

### modules: [audit] を使う場合に追加

| ファイル | 説明 |
|---------|------|
| `done-criteria/*.md` | 各フェーズの監査基準。`audit: required \| lite` をフロントマターに宣言 |

### modules: [regate] を使う場合に追加

| ファイル | 説明 |
|---------|------|
| `regate/*.md` | Regate 戦略ファイル |
| pipeline.yml `regate` セクション | `verification_chain`, トリガー定義 |

### 任意

| ファイル | 説明 |
|---------|------|
| `references/*.md` | パイプライン固有の参照ドキュメント |

### 最小構成例（仮想パイプライン: quick-fix）

```
skills/quick-fix/
  SKILL.md            # フラグ定義 + workflow-engine invoke
  pipeline.yml        # modules: [resume, phase-summary, context-budget] のみ（audit なし）
  phases/
    diagnose.md
    fix.md
    verify.md
```

audit, regate を含めない軽量パイプラインも workflow-engine で駆動可能。

---

## 9. 移行時の変更サマリ

### ファイル操作

| 操作 | ファイル |
|-----|---------|
| **新規作成** | `workflow-engine/SKILL.md` |
| **新規作成** | `workflow-engine/modules/audit.md` |
| **新規作成** | `workflow-engine/modules/autonomy.md` |
| **新規作成** | `workflow-engine/modules/regate.md` |
| **新規作成** | `workflow-engine/modules/phase-summary.md` |
| **新規作成** | `workflow-engine/modules/context-budget.md` |
| **新規作成** | `workflow-engine/modules/resume.md` |
| **新規作成** | `workflow-engine/modules/inner-loop.md` |
| **書き換え** | `feature-dev/SKILL.md` → 薄いラッパーに |
| **書き換え** | `debug-flow/SKILL.md` → 薄いラッパーに |
| **書き換え** | `feature-dev/pipeline.yml` → version: 2, modules 追加, execute に uses 追加 |
| **書き換え** | `debug-flow/pipeline.yml` → version: 2, modules 追加, execute に uses 追加 |
| **編集** | `claude/CLAUDE.md` → Audit Gate セクション削除 |
| **削除** | `feature-dev/references/audit-gate-protocol.md` |
| **削除** | `feature-dev/references/autonomy-gates.md` |
| **削除** | `feature-dev/references/inner-loop-protocol.md` |
| **削除** | `debug-flow/references/audit-gate-protocol.md` (symlink) |
| **削除** | `debug-flow/references/autonomy-gates.md` (symlink) |
| **削除** | `debug-flow/references/inner-loop-protocol.md` |
| **削除** | `debug-flow/references/` ディレクトリ |

### 軽微な変更

- `feature-dev/phases/execute.md`: フロントマターの `phase_references` から `inner-loop-protocol.md` 参照を削除（engine が `uses` 経由で注入するため）
- `debug-flow/phases/execute.md`: 同上

### 影響のないファイル

- `feature-dev/phases/*.md` (execute.md 以外の8ファイル): 変更なし
- `feature-dev/done-criteria/*.md` (9ファイル): 変更なし
- `feature-dev/regate/*.md` (3ファイル): 変更なし
- `feature-dev/references/brainstorming-supplement.md`: 残存
- `debug-flow/phases/*.md` (execute.md 以外の7ファイル): 変更なし
- `debug-flow/done-criteria/*.md` (8ファイル): 変更なし
- `debug-flow/regate/*.md` (3ファイル): 変更なし
- 他の全スキル: 変更なし

### continue / handover への影響

- `continue/SKILL.md`: pipeline フィールドの読み取りロジックは変更なし（project-state.json の構造は不変）
- `handover/SKILL.md`: Phase Summary フォーマットは modules/phase-summary.md に移動するが、フォーマット自体は不変
- これらのスキルは workflow-engine を invoke しない（独立スキルのまま）

### phases/*.md のフロントマター更新

Execute フェーズの phase_references から inner-loop-protocol.md の参照を削除する必要がある（modules/inner-loop.md は engine が `uses` 経由で注入するため）:

**feature-dev/phases/execute.md と debug-flow/phases/execute.md:**

```yaml
# Before
phase_references:
  - references/inner-loop-protocol.md

# After（削除、または空にする）
phase_references: []
```

---

## 10. 既存設計書との関係

### 2026-04-04-phase-module-architecture-design.md

Phase Module Architecture（フェーズモジュール分割 + 遅延ロード）は**実装済み**。本設計はその上に構築される次のレイヤー:

- Phase Module Architecture: SKILL.md → phases/ + done-criteria/ + regate/ への分割（完了）
- **本設計**: SKILL.md 内のオーケストレーションロジック → workflow-engine への抽出

Phase Module Architecture が「フェーズの外出し」、本設計が「エンジンの外出し」。

### 2026-04-04-semantic-phase-naming-design.md

セマンティックフェーズ命名（phase-01 → design 等）は**実装済み**。pipeline.yml のフェーズ ID はセマンティック命名を使用しており、本設計はこれに依存する。

### 2026-04-04-execute-inner-loop-design.md

Inner Loop Protocol は本設計で `workflow-engine/modules/inner-loop.md` に移動する。設計内容自体は不変。
