# pipeline.yml バリデーションテスト設計書

## 目的

`pipeline.v2.schema.json` に準拠しているか、参照ファイルが実在するか、セマンティックな整合性が保たれているかを自動検証し、push 前のレグレッション検知を実現する。

## 制約・前提

- ランタイム: Deno 2.x（`deno test --allow-read`）
- git hook は使わない。CLAUDE.md に規約として記述し、push 前の手動実行で運用する
- テスト対象の pipeline.yml は `claude/skills/**/pipeline.yml` を glob で自動検出する
- `deno.json` は不要。`npm:` / `jsr:` インラインインポートで依存解決する

## ファイル構成

```
spec/pipeline/
  pipeline_test.ts    # 全検証ロジック（単一ファイル）
```

## 実行コマンド

```bash
deno test --allow-read spec/pipeline/
```

パーミッションは `--allow-read` のみ。ファイルシステムの読み取り（スキーマ、pipeline.yml、参照先ファイルの存在確認）だけで完結する。

## パイプライン自動検出

`claude/skills/**/pipeline.yml` を `@std/fs/walk` で走査する。新しいパイプラインを追加した場合、テストコードの修正は不要。

## 検証の3レイヤー

### Layer 1: JSON Schema バリデーション

`npm:ajv/dist/2020`（Draft 2020-12 対応）で `pipeline.v2.schema.json` に対して検証する。

検出範囲:

- 必須フィールドの欠落（`pipeline`, `version`, `modules`, `phases`, `settings`）
- 型・パターン違反（`id` の命名規則 `^[a-z][a-z0-9-]*$`、`enabled_by` の `--` プレフィックスなど）
- 条件付き必須（`modules` に `audit` → 全フェーズに `done_criteria` 必須、`regate` モジュール → `regate` セクション必須）
- `skip` / `skip_unless` の排他制約（`not: { required: [skip, skip_unless] }`）

### Layer 2: ファイル参照の実在性

pipeline.yml が参照するファイルパスを、スキルディレクトリ（pipeline.yml の親ディレクトリ）を基準に解決し、実在を確認する。

| 参照元 | 解決ベース | 例 |
|-------|----------|---|
| `phases[].phase_file` | スキルディレクトリ | `phases/design.md` → `claude/skills/feature-dev/phases/design.md` |
| `phases[].done_criteria` | スキルディレクトリ | `done-criteria/design.md` → `claude/skills/feature-dev/done-criteria/design.md` |
| `regate.*.strategy_file` | スキルディレクトリ | `regate/review-findings.md` → `claude/skills/feature-dev/regate/review-findings.md` |
| `modules[]` | `workflow-engine/modules/` | `audit` → `claude/skills/workflow-engine/modules/audit.md` |
| `phases[].uses[]` | `workflow-engine/modules/` | `inner-loop` → `claude/skills/workflow-engine/modules/inner-loop.md` |

### Layer 3: セマンティック整合性

JSON Schema では表現できないクロスリファレンスの検証。

| チェック | 内容 |
|---------|------|
| フェーズ ID 一意性 | `phases[].id` にパイプライン内で重複がないこと |
| verification_chain 参照 | `regate.verification_chain` の全 ID が `phases[].id` に存在すること |
| rewind_to 参照 | 各 regate 戦略の `rewind_to` が有効なフェーズ ID または `"current"` であること |
| produces 一意性 | 同一パイプライン内でアーティファクト名が重複しないこと |

## テスト構造

自動検出した各 pipeline.yml に対して `Deno.test` のサブテストを動的生成する。パイプライン名（ディレクトリ名）がテスト名に含まれるので、どのパイプラインで何が壊れたか一目でわかる。

```typescript
Deno.test("pipeline validation", async (t) => {
  const pipelines = await discoverPipelines();

  for (const { name, path, skillDir, data } of pipelines) {
    await t.step(`[${name}] schema validation`, () => { ... });
    await t.step(`[${name}] file references`, async () => { ... });
    await t.step(`[${name}] semantic consistency`, () => { ... });
  }
});
```

## 依存ライブラリ

| パッケージ | 用途 |
|-----------|------|
| `npm:ajv/dist/2020` | JSON Schema Draft 2020-12 バリデーション |
| `jsr:@std/yaml` | YAML パース |
| `jsr:@std/fs/walk` | pipeline.yml の自動検出 |
| `jsr:@std/path` | パス解決 |
| `jsr:@std/assert` | テストアサーション |

## CLAUDE.md への追記

```markdown
## パイプラインバリデーション

- `pipeline.yml` またはスキーマ（`pipeline.v2.schema.json`）を変更した場合、push 前に `deno test --allow-read spec/pipeline/` を実行すること
```

## 設計判断

### 単一ファイル構成を選択した理由

検証対象は現時点で2パイプライン × 3レイヤー。バリデータモジュールの分離やレイヤー別ファイル分割は YAGNI。肥大化した場合にその時点で分割すればよい。

### deno.json を置かない理由

Deno 2.x は `npm:` / `jsr:` インラインインポートをネイティブサポートしており、設定ファイルなしで動作する。依存はテストファイル内のインポート文で完結し、管理ファイルを増やさない。

### git hook ではなく CLAUDE.md 規約とした理由

ユーザーの要件。コミットのたびに実行するほどの頻度は不要で、push 前のチェックポイントとして十分。
