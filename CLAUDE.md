# Dotfiles — プロジェクト規約

## ワークフローエンジンアーキテクチャ

### 設計思想

このリポジトリの `claude/skills/` は、パイプライン型ワークフロー（feature-dev, debug-flow 等）を共通エンジンで駆動する構造を取る。

**3つの原則:**

1. **Engine Takeover** — オーケストレーション（フェーズ遷移、監査、regate、handover、integration hooks）は `workflow-engine` に一元化する。パイプラインスキルはフラグ定義 + engine invoke のみの薄いラッパーとする
2. **Pluggable Modules** — 監査プロトコル、regate、inner-loop 等の知識は `workflow-engine/modules/` に配置し、pipeline.yml の宣言で DI 的に注入する。エンジン本体を変更せず機能を追加・除外できる
3. **Schema as SSOT** — pipeline.yml の構造は `workflow-engine/schema/pipeline.v2.schema.json`（JSON Schema Draft 2020-12）が唯一の正式定義。散文での構造記述はスキーマへの参照に留める

### ディレクトリ構造

```
claude/skills/
├── workflow-engine/          # 内部スキル（user-invocable: false）
│   ├── SKILL.md              # オーケストレーションループ
│   ├── schema/               # pipeline.yml の JSON Schema（SSOT）
│   └── modules/              # プラガブルモジュール群
│       ├── audit.md          # 監査プロトコル（憲法的ルール含む）
│       ├── regate.md         # Regate ディスパッチ
│       ├── inner-loop.md     # TDD + TestEnrich + Verify サイクル
│       └── ...
├── feature-dev/              # パイプラインスキル（薄いラッパー）
│   ├── SKILL.md              # フラグ定義 + engine invoke
│   ├── pipeline.yml          # パイプライン定義（schema 準拠）
│   ├── phases/               # フェーズ固有の実行指示
│   ├── done-criteria/        # フェーズ固有の監査基準
│   └── regate/               # フェーズ固有の regate 戦略
└── debug-flow/               # 同構造
```

### モジュール注入の2レベル

| レベル | 宣言場所 | 読み込みタイミング | 例 |
|-------|---------|------------------|---|
| エンジンレベル | `pipeline.yml` の `modules:` | オーケストレーションループの該当ステップ | audit, regate, resume |
| フェーズレベル | `pipeline.yml` フェーズ定義の `uses:` | フェーズ実行準備時 | inner-loop |

### Integration Hooks

外部スキルとの連携は `pipeline.yml` の `integrations:` セクションで宣言する。エンジンはライフサイクルイベント（on_phase_complete, on_regate 等）を発火し、登録されたスキルを invoke する。エンジン本体は特定の外部スキル（Linear, Slack 等）の存在を知らない。

### 新パイプラインの追加方法

1. `skills/<pipeline-name>/` ディレクトリを作成
2. `SKILL.md` — フラグ定義 + `Skill("workflow-engine", "${CLAUDE_SKILL_DIR} {flags} {task}")` の invoke
3. `pipeline.yml` — `pipeline.v2.schema.json` に準拠。使用する modules を宣言
4. `phases/*.md` — 各フェーズの実行指示
5. modules に `audit` を含む場合: `done-criteria/*.md`
6. modules に `regate` を含む場合: `regate/*.md` + pipeline.yml の regate セクション

### 新モジュールの追加方法

1. `workflow-engine/modules/<name>.md` にプロトコルを記述
2. pipeline.yml の `modules:` または `uses:` に名前を追加
3. engine の SKILL.md にモジュール読み込みポイントを追加（エンジンレベルの場合）

### 監査ルールの所在

Audit Gate の憲法的ルール（スキップ禁止等）は `workflow-engine/modules/audit.md` 冒頭に定義されている。`claude/CLAUDE.md`（グローバル規約）には含めない — ワークフロー固有のルールはワークフローシステム内で管理する。
