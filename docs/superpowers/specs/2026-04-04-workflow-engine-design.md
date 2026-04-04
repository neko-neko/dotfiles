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
│   ├── schema/
│   │   └── pipeline.v2.schema.json          # pipeline.yml の JSON Schema 定義
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
  Phase Dispatch, Audit Gate, Regate, Handover, Integration Hooks を駆動する。
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
   ├── Integration Hooks: on_phase_complete イベント発火
   │   └── pipeline.yml の integrations を走査
   │   └── enabled_by フラグが有効な integration の hooks を実行
   │   └── 各 hook: 対応スキルを Skill tool で invoke
   │
   └── Regate チェック（modules に regate が含まれ、トリガー検出時）
       ├── Integration Hooks: on_regate イベント発火
       ├── Read ${CLAUDE_SKILL_DIR}/modules/regate.md → プロトコル実行
       ├── Read $PIPELINE_DIR/regate/{strategy}.md → 戦略適用
       └── rewind_to フェーズから再実行

4. 完了処理
   ├── Integration Hooks: on_pipeline_complete イベント発火
   └── Handover 生成 / Knowledge Capture
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

## 4. pipeline.yml スキーマ定義

pipeline.yml は workflow-engine が読み取って解釈する設定ファイルである。スキーマは JSON Schema (Draft 2020-12) で正式に定義し、`workflow-engine/schema/pipeline.v2.schema.json` に配置する。

### 4.1 JSON Schema

各 pipeline.yml の先頭に以下のコメントを付与することで、IDE（VS Code, JetBrains 等）でバリデーション + 自動補完が有効になる:

```yaml
# yaml-language-server: $schema=../../workflow-engine/schema/pipeline.v2.schema.json
pipeline: feature-dev
version: 2
...
```

スキーマファイルの配置:

```
workflow-engine/
  SKILL.md
  schema/
    pipeline.v2.schema.json    # 正式スキーマ定義
  modules/
    ...
```

スキーマの全体構造（`workflow-engine/schema/pipeline.v2.schema.json`）:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "pipeline.v2.schema.json",
  "title": "Workflow Engine Pipeline Definition",
  "description": "workflow-engine が駆動するパイプラインの定義スキーマ (v2)。このファイルが pipeline.yml 構造の SSOT（Single Source of Truth）である。",
  "type": "object",
  "required": ["pipeline", "version", "modules", "phases", "settings"],
  "additionalProperties": false,

  "properties": {
    "pipeline": {
      "type": "string",
      "description": "パイプラインの識別子。handover 時に project-state.json の pipeline フィールドと照合される。小文字英数字とハイフンのみ使用可能。",
      "pattern": "^[a-z][a-z0-9-]*$",
      "examples": ["feature-dev", "debug-flow", "quick-fix"]
    },

    "version": {
      "type": "integer",
      "const": 2,
      "description": "pipeline.yml のスキーマバージョン。workflow-engine はこの値を読み取り、未知のバージョンの場合は PAUSE してユーザーに通知する。"
    },

    "modules": {
      "type": "array",
      "description": "エンジンレベルモジュールのリスト。ここに記載した名前に対応する workflow-engine/modules/{name}.md がオーケストレーションループの該当ステップで読み込まれる。新規モジュールを追加する場合は modules/ にファイルを配置し、ここに名前を追加するだけでよい。",
      "items": {
        "type": "string",
        "pattern": "^[a-z][a-z0-9-]*$",
        "examples": ["audit", "autonomy", "regate", "resume", "phase-summary", "context-budget"]
      },
      "minItems": 1,
      "uniqueItems": true
    },

    "phases": {
      "type": "array",
      "description": "パイプラインのフェーズ定義。配列の順序がそのまま実行順になる。最低1つのフェーズが必要。",
      "items": { "$ref": "#/$defs/Phase" },
      "minItems": 1
    },

    "integrations": {
      "type": "array",
      "description": "ライフサイクルフックで呼び出す外部スキルの定義。パイプラインの各イベント（フェーズ完了、regate 発生など）で自動的に invoke される。フラグで有効/無効を切り替える。未定義の場合、フックは一切発火しない。",
      "items": { "$ref": "#/$defs/Integration" }
    },

    "regate": {
      "$ref": "#/$defs/Regate",
      "description": "Regate（失敗時の巻き戻し＋再実行）の設定。modules に 'regate' を含む場合は必須。"
    },

    "settings": {
      "$ref": "#/$defs/Settings",
      "description": "パイプライン全体の設定。handover ポリシー、リトライ上限、コンテキスト予算を定義する。"
    }
  },

  "allOf": [
    {
      "if": {
        "properties": {
          "modules": { "contains": { "const": "regate" } }
        }
      },
      "then": {
        "required": ["regate"],
        "description": "modules に 'regate' を含む場合、regate セクションの定義が必須。"
      }
    },
    {
      "if": {
        "properties": {
          "modules": { "contains": { "const": "audit" } }
        }
      },
      "then": {
        "properties": {
          "phases": {
            "items": {
              "required": ["done_criteria"]
            }
          }
        },
        "description": "modules に 'audit' を含む場合、全フェーズに done_criteria の定義が必須。"
      }
    }
  ],

  "$defs": {

    "Phase": {
      "type": "object",
      "description": "1つのフェーズの定義。フェーズはパイプラインの実行単位で、それぞれが独立した .md ファイルに実行手順を持つ。",
      "required": ["id", "phase_file", "produces"],
      "additionalProperties": false,
      "properties": {
        "id": {
          "type": "string",
          "description": "フェーズのセマンティック ID。パイプライン内で一意でなければならない。regate の rewind_to や verification_chain でこの ID を参照する。",
          "pattern": "^[a-z][a-z0-9-]*$",
          "examples": ["design", "execute", "review", "rca", "fix-plan"]
        },

        "phase_file": {
          "type": "string",
          "description": "フェーズの実行手順が書かれた .md ファイルへのパス。パイプラインスキルのディレクトリからの相対パス。",
          "examples": ["phases/design.md", "phases/execute.md"]
        },

        "done_criteria": {
          "type": "string",
          "description": "このフェーズの監査基準ファイルへのパス。modules に 'audit' を含む場合は全フェーズで必須。ファイル内のフロントマターで audit: required（phase-auditor エージェント起動）または audit: lite（エンジンが直接検証）を指定する。",
          "examples": ["done-criteria/design.md", "done-criteria/execute.md"]
        },

        "skip": {
          "type": "boolean",
          "default": false,
          "description": "true にするとこのフェーズは常にスキップされる。skip_unless と同時に指定することはできない（排他）。省略時は false（スキップしない）。"
        },

        "skip_unless": {
          "type": "string",
          "description": "ここで指定したフラグがユーザーに渡されない限り、このフェーズはスキップされる。例: '--accept' を指定すると、ユーザーが --accept フラグを付けた場合のみ実行。skip と同時に指定することはできない（排他）。",
          "pattern": "^--[a-z][a-z0-9-]*$",
          "examples": ["--accept", "--doc"]
        },

        "uses": {
          "type": "array",
          "description": "このフェーズの実行前に追加で読み込むモジュール（フェーズレベルモジュール）。workflow-engine/modules/{name}.md が注入される。例えば Execute フェーズに inner-loop を指定すると、TDD サイクルのプロトコルが注入される。",
          "items": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9-]*$",
            "examples": ["inner-loop"]
          },
          "uniqueItems": true
        },

        "handover": {
          "type": "string",
          "enum": ["always", "optional", "never"],
          "description": "フェーズ完了後の handover（セッション引き継ぎ）ポリシー。always: 毎回 handover。optional: コンテキスト残量が不足した場合のみ。never: handover しない（ただし critical 閾値を下回った場合は例外）。省略時は settings.default_handover の値が使われる。"
        },

        "produces": {
          "type": "array",
          "description": "このフェーズが生成するアーティファクト（成果物）の名前リスト。後続フェーズが requires_artifacts でこの名前を参照し、Phase Summary チェーンから解決する。",
          "items": {
            "type": "string",
            "examples": ["spec_file", "code_changes", "test_results", "review_findings"]
          },
          "minItems": 1
        }
      },
      "not": {
        "description": "skip と skip_unless は同時に指定できない。skip: true は「常にスキップ」、skip_unless は「フラグがない場合にスキップ」で意味が矛盾するため。",
        "required": ["skip", "skip_unless"]
      }
    },

    "Integration": {
      "type": "object",
      "description": "外部スキルとのインテグレーション定義。パイプラインのライフサイクルイベントに応じて、指定したスキルを自動的に invoke する。例: Linear チケットへの進捗同期、Slack への通知など。",
      "required": ["skill", "enabled_by", "hooks"],
      "additionalProperties": false,
      "properties": {
        "skill": {
          "type": "string",
          "description": "invoke するスキルの名前。Claude Code に登録されたスキル名を指定する。",
          "examples": ["linear-sync", "slack-notify"]
        },

        "enabled_by": {
          "type": "string",
          "description": "このインテグレーションを有効化するフラグ名。ユーザーがこのフラグを指定した場合のみ hooks が発火する。",
          "pattern": "^--[a-z][a-z0-9-]*$",
          "examples": ["--linear", "--slack"]
        },

        "hooks": {
          "type": "object",
          "description": "ライフサイクルイベントと、そのイベント発火時に実行するアクションのマッピング。キーはイベント名、値はスキルに渡すアクション名の配列。",
          "propertyNames": {
            "enum": [
              "on_pipeline_start",
              "on_phase_start",
              "on_phase_complete",
              "on_audit_fail",
              "on_regate",
              "on_handover",
              "on_pipeline_complete"
            ],
            "description": "使用可能なライフサイクルイベント名"
          },
          "additionalProperties": {
            "type": "array",
            "description": "イベント発火時に実行するアクション名のリスト。スキルに引数として渡される。",
            "items": {
              "type": "string",
              "examples": ["sync_phase_summary", "sync_evidence", "sync_regate"]
            },
            "minItems": 1
          },
          "minProperties": 1,
          "examples": [
            {
              "on_pipeline_start": ["sync_workflow_start"],
              "on_phase_complete": ["sync_phase_summary", "sync_evidence"],
              "on_pipeline_complete": ["sync_complete"]
            }
          ]
        }
      }
    },

    "Regate": {
      "type": "object",
      "description": "Regate（Re-gate）は、失敗が発生した際にパイプラインを特定のフェーズまで巻き戻して再実行する仕組み。verification_chain で再実行するフェーズ群を定義し、各トリガー（レビュー指摘、テスト失敗、監査失敗など）ごとに戦略ファイルを指定する。トリガー名はパイプライン固有に自由に定義できる。",
      "required": ["verification_chain"],
      "properties": {
        "verification_chain": {
          "type": "array",
          "description": "Regate 発生時に再実行するフェーズ ID のリスト。ここで指定した順序でフェーズが再実行される。例: [execute, accept-test, review] なら、修正後に実装→受入テスト→レビューを再実行する。",
          "items": {
            "type": "string",
            "examples": ["execute", "accept-test", "review"]
          },
          "minItems": 1
        }
      },
      "additionalProperties": {
        "$ref": "#/$defs/RegateStrategy",
        "description": "各トリガーの Regate 戦略。キー名はトリガーの識別子（例: review_findings, test_failure, audit_failure, security_failure など）。パイプライン固有のトリガーを自由に追加できる。"
      }
    },

    "RegateStrategy": {
      "type": "object",
      "description": "1つの Regate トリガーの戦略定義。どのファイルに戦略が書かれているか、どのフェーズまで巻き戻すか、何回までリトライするかを指定する。",
      "required": ["strategy_file", "rewind_to"],
      "additionalProperties": false,
      "properties": {
        "strategy_file": {
          "type": "string",
          "description": "Regate 戦略が記述されたファイルのパス。パイプラインスキルのディレクトリからの相対パス。",
          "examples": ["regate/review-findings.md", "regate/test-failure.md"]
        },
        "rewind_to": {
          "type": "string",
          "description": "巻き戻し先のフェーズ ID。'current' を指定すると、コード変更なしで現フェーズの Audit Gate のみを再実行する。",
          "examples": ["execute", "plan", "current"]
        },
        "max_retries": {
          "type": "integer",
          "minimum": 1,
          "description": "この戦略の最大リトライ回数。超過すると PAUSE してユーザーに判断を委ねる。省略時は settings.max_phase_retries の値が使われる。",
          "examples": [3]
        }
      }
    },

    "Settings": {
      "type": "object",
      "description": "パイプライン全体に適用される設定。",
      "required": ["default_handover", "max_phase_retries", "context_budget"],
      "additionalProperties": false,
      "properties": {
        "default_handover": {
          "type": "string",
          "enum": ["always", "optional", "never"],
          "description": "フェーズ定義で handover を省略した場合に適用されるデフォルトポリシー。always: 毎フェーズ handover。optional: コンテキスト残量で判定。never: handover しない。",
          "examples": ["always"]
        },
        "max_phase_retries": {
          "type": "integer",
          "minimum": 1,
          "description": "Audit Gate 失敗時のデフォルト最大リトライ回数。RegateStrategy で個別に上書き可能。",
          "examples": [3]
        },
        "context_budget": {
          "$ref": "#/$defs/ContextBudget"
        }
      }
    },

    "ContextBudget": {
      "type": "object",
      "description": "コンテキストウィンドウの予算配分。各カテゴリにトークン数を割り当て、handover: optional 時の判定基準に使われる。",
      "required": ["orchestrator", "phase", "references"],
      "additionalProperties": false,
      "properties": {
        "orchestrator": {
          "type": "integer",
          "minimum": 1,
          "description": "SKILL.md + pipeline.yml のロードに使うトークン予算。",
          "examples": [150]
        },
        "phase": {
          "type": "integer",
          "minimum": 1,
          "description": "phases/*.md + done-criteria/*.md のロードに使うトークン予算。",
          "examples": [100]
        },
        "references": {
          "type": "integer",
          "minimum": 1,
          "description": "references/*.md + modules/*.md のロードに使うトークン予算。",
          "examples": [200]
        }
      }
    }
  }
}
```

### 4.2 ライフサイクルイベント定義

integrations の hooks で使用可能なイベント:

| イベント | 発火タイミング | 引数 |
|---------|-------------|------|
| `on_pipeline_start` | パイプライン開始時 | pipeline 名, フラグ, タスク記述 |
| `on_phase_start` | フェーズ実行前 | phase_id |
| `on_phase_complete` | フェーズ完了 + Audit Gate PASS 後 | phase_id, Phase Summary |
| `on_audit_fail` | Audit Gate FAIL 時 | phase_id, failed_criteria, attempt |
| `on_regate` | Regate 発生時 | trigger, rewind_to, fix_summary |
| `on_handover` | Handover 実行時 | phase_id, session 情報 |
| `on_pipeline_complete` | パイプライン全体完了時 | pipeline 名, 最終ステータス |

### 4.3 バージョニング

| version | 対応設計書 | 変更点 |
|---------|-----------|-------|
| 1 | phase-module-architecture-design | 初版。phases, regate, settings |
| 2 | **本設計（workflow-engine）** | modules, uses, integrations 追加。settings.linear_sync 削除（integrations に移行） |

workflow-engine は `version` フィールドを読み取り、未知のバージョンの場合は PAUSE してユーザーに通知する。

### 4.4 feature-dev/pipeline.yml（改定後）

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
    done_criteria: done-criteria/design.md
    produces:
      - spec_file
      - investigation_record

  - id: spec-review
    phase_file: phases/spec-review.md
    done_criteria: done-criteria/spec-review.md
    produces:
      - review_report

  - id: plan
    phase_file: phases/plan.md
    done_criteria: done-criteria/plan.md
    produces:
      - implementation_plan
      - test_cases

  - id: plan-review
    phase_file: phases/plan-review.md
    done_criteria: done-criteria/plan-review.md
    produces:
      - review_report

  - id: execute
    phase_file: phases/execute.md
    done_criteria: done-criteria/execute.md
    uses: [inner-loop]
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
  context_budget:
    orchestrator: 150
    phase: 100
    references: 200
```

### 4.5 debug-flow/pipeline.yml（改定後）

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
    done_criteria: done-criteria/rca.md
    produces:
      - rca_report
      - reproduction_test

  - id: fix-plan
    phase_file: phases/fix-plan.md
    done_criteria: done-criteria/fix-plan.md
    produces:
      - fix_plan

  - id: fix-plan-review
    phase_file: phases/fix-plan-review.md
    done_criteria: done-criteria/fix-plan-review.md
    produces:
      - review_report

  - id: execute
    phase_file: phases/execute.md
    done_criteria: done-criteria/execute.md
    uses: [inner-loop]
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
- `--linear`: Linear インテグレーションを有効化（pipeline.yml の integrations で定義）
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

workflow-engine を利用する新規パイプラインが満たすべき要件。YAML の構造は `pipeline.v2.schema.json`（SSOT）に準拠すること。

### ファイル構成

| ファイル | 必須 | 説明 |
|---------|------|------|
| `SKILL.md` | 必須 | エントリポイント。フラグ定義 + workflow-engine の invoke |
| `pipeline.yml` | 必須 | パイプライン定義。スキーマ: `pipeline.v2.schema.json` |
| `phases/*.md` | 必須 | 各フェーズの実行指示 |
| `done-criteria/*.md` | modules に audit を含む場合 | 各フェーズの監査基準 |
| `regate/*.md` | modules に regate を含む場合 | Regate 戦略ファイル |
| `references/*.md` | 任意 | パイプライン固有の参照ドキュメント |

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
| **新規作成** | `workflow-engine/schema/pipeline.v2.schema.json` |
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
