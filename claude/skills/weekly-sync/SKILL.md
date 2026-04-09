---
name: weekly-sync
description: >-
  Linear（SSOT）と顧客向け出力先（GitHub Project 等）の間で定例ミーティング向けの
  週次同期を実行する。チケットのスキャン・差分分析・顧客向けDocument作成・出力先転写・
  ステータス同期を一気通貫で行う。プロジェクト固有の設定は .weekly-sync/config.md で管理。
argument-hint: "{from}..{to} [--setup] [--dry-run]"
---

# Weekly Sync

Linear（SSOT）と顧客向け出力先の間で、定例ミーティング向けの週次同期を実行する。

## Options

| Option | 効果 |
|--------|------|
| `{from}..{to}` | 同期対象期間を指定（ISO 8601 or YYYY-MM-DD） |
| `{from}..` | from のみ指定（to は今日） |
| `--setup` | 設定ウィザードのみ実行 |
| `--dry-run` | Scan + Analyze まで実行し、変更は行わない |

## Prerequisites

- `linear` CLI が利用可能であること: `which linear && linear --version`
- 出力先 CLI が利用可能であること（GitHub: `gh --version`）
- `--setup` 以外では `.weekly-sync/config.md` が存在すること

## Workflow

```
Phase 0: Setup    — config.md 確認。なければウィザード起動
Phase 1: Scan     — Linear + 出力先を並列スキャン
Phase 2: Analyze  — 差分分析 → 同期計画生成
Phase 3: Approve  — 計画をユーザーに提示、承認待ち
Phase 4: Sync     — SSOT更新 → Document作成 → 出力先転写 → ステータス同期
Phase 5: Verify   — 最終検証 → 結果レポート
```

**開始時アナウンス:** 「Weekly Sync を開始します。期間: {from} → {to}」

## Phase 0: Setup

1. `.weekly-sync/config.md` の存在を確認する。
2. **存在しない or `--setup` 指定の場合:**
   [setup-wizard.md](references/setup-wizard.md) を読み込み、ウィザードを起動する。
   `--setup` 時はウィザード完了で終了。
3. **存在する場合:** YAML frontmatter をパースし、必須フィールドを検証する。
   必須: `linear_team`, `linear_workspace`, `output_adapter`, ステータスマッピング, リライト原則。
   不足があればユーザーに報告し、`--setup` での再設定を提案。
4. 引数から `{from}` と `{to}` をパースする。
   `..` 区切りで分割。`{to}` 省略時は今日の日付。
   日付が不正ならエラー終了。

## Phase 1: Scan

2つのサブエージェントを**並列**ディスパッチする。
サブエージェント指示: [scan-agent.md](references/scan-agent.md)

**Agent A: Linear スキャン**

config の `linear_team` を使い、`{from}` 以降に更新されたチケットを全件取得する。

```bash
linear issue list --team {linear_team} --all-states --updated-after {from} --limit 0 --json --no-pager
```

各チケットについて詳細を取得:
```bash
linear issue view {identifier} --json --no-pager
```

収集する情報:
- identifier, title, state, priority, labels
- description の要約
- 外部リンク（Slack, Google Sheets, Drive, GitHub PR/Issue 等）
- `{from}` 以降のコメント
- SSOT 更新提案（ステータス不整合、リンク欠落等）

**Agent B: 出力先スキャン**

config の `output_adapter` に応じたアダプタ仕様を読み込む:
- GitHub: [github-adapter.md](references/github-adapter.md)

アダプタの `scan_existing` と `scan_new_external` を実行。

**結果:** 両エージェントの結果を `.weekly-sync/scan.json` にマージ。

```json
{
  "period": { "from": "{from}", "to": "{to}" },
  "linear": {
    "updated_tickets": [...],
    "external_links": [...],
    "ssot_proposals": [...]
  },
  "output": {
    "existing_items": [...],
    "new_external_items": [...]
  }
}
```

## Phase 2: Analyze

scan.json を読み込み、差分を分類する。
出力フォーマット: [analysis-template.md](references/analysis-template.md)

**分類基準:**

1. **新規追加:** Linear に存在するが出力先に未登録のチケット（Linear ID で照合）、または出力先に存在するが Linear に未登録のアイテム。
2. **ステータス変更:** 出力先の既存アイテムで、Linear の現在ステータスをマッピングした値と出力先のステータスが不一致。
3. **コンテキスト更新:** DONE でない既存アイテムで、期間内に新しいコメント・外部リンクが追加されたもの。

**同期対象:** 上記3カテゴリすべてのユニークチケット。定例 Document 作成対象となる。

結果を `.weekly-sync/sync-plan.json` に書き出す。

**`--dry-run` 時はここで終了。** 計画をテーブル形式で表示して完了。

## Phase 3: Approve

sync-plan.json をテーブル形式でユーザーに提示する。

```
## Weekly Sync Plan ({from} → {to})

### 新規追加（N件）
| Linear ID | 出力先 | タイトル | ステータス | アクション |
|-----------|-------|---------|---------|-----------|
| {id} | (新規作成) | {title} | {status} | 出力先アイテム作成 + ボード追加 |

### ステータス変更（N件）
| Linear ID | 出力先 ID | 変更 |
|-----------|---------|------|
| {id} | {output_id} | {from_status} → {to_status} |

### コンテキスト更新（N件）
| Linear ID | 出力先 ID | 更新内容の要約 |
|-----------|---------|--------------|
| {id} | {output_id} | {summary} |

### Linear SSOT 更新（N件）
| Linear ID | 更新種別 | 提案内容 | 理由 |
|-----------|---------|---------|------|
| {id} | {type} | {proposal} | {reason} |

### 定例 Document 作成対象（N件）
上記すべての同期対象チケット

---
Approve? (ok / modify / cancel)
```

- `ok` → Phase 4 へ
- ID指定で修正指示 → sync-plan.json を更新し、再提示
- `cancel` → 終了

## Phase 4: Sync

承認済み計画を順序付きで実行する。

### Step 1: Linear SSOT 更新

sync-plan.json の `ssot_updates` を実行:

```bash
# ステータス変更
linear issue update {identifier} --state "{new_state}"

# コメント追加
linear issue comment add {identifier} --body "{context}"
```

### Step 2: 紐づけ

**新規 Linear チケット → 出力先アイテム作成:**

config の `rewrite_principles` と `terminology` を適用して顧客向けタイトル・本文を生成。
アダプタの `create_item` → `add_to_board` を実行。

**新規出力先アイテム → Linear チケット作成:**

```bash
linear issue create --team {linear_team} --title "{title}" --state "Todo"
```

作成後、アダプタの `add_to_board` でフィールド設定。

**出力先アイテムの body が空・不十分な場合:** アダプタの `update_item` で更新。

### Step 3: Linear Document 作成（ユーザーレビューゲート）

同期対象の各チケットについて、定例 Document を作成する。

1. スキャン結果のコンテキスト（コメント、外部リンク）を基に、config の `rewrite_principles` と `terminology` を適用してドラフトを生成する。
   テンプレート: [document-template.md](references/document-template.md)

2. **ドラフトを一覧でユーザーに提示し、レビューを待つ。**
   修正指示があればドラフトを更新。

3. 承認後、Linear に Document を作成:

```bash
linear document create \
  --title "[{document_prefix} {to}] {customer_facing_title}" \
  --content-file {draft_file} \
  --issue {identifier}
```

### Step 4: 出力先転写

アダプタの `add_comment` を使い、Document 内容を出力先に投稿。

コメントテンプレート:
```markdown
### {to} 定例アップデート

**進捗:** {progress}

**現在の状況:** {status}

**次のアクション:** {next_action}
```

新規アイテムの場合は Step 2 で body 作成済みなので、コメントのみ追加。

### Step 5: ステータス同期

アダプタの `update_status` を使い、出力先のステータスを Linear と一致させる。
config の `status_mapping` に基づいてマッピング。

## Phase 5: Verify

1. 出力先のアイテム総数・ステータス分布を確認
2. Linear Document 件数を確認（`linear document list` で `{document_prefix} {to}` を検索）
3. サンプル3件の出力先コメントを確認（`{to} 定例アップデート` ヘッダーの存在、技術用語の不在、3セクション構成）
4. 結果サマリーを表示:

```
## Weekly Sync 完了

- **出力先アイテム数:** N件（+M件 新規追加）
- **ステータス更新:** N件
- **Linear Document [{document_prefix} {to}] 作成:** N件
- **出力先コメント投稿:** N件
- **Linear SSOT 更新:** N件
```

5. 中間アーティファクト（`.weekly-sync/scan.json`, `.weekly-sync/sync-plan.json`）を削除

## Red Flags

**禁止事項:**
- Phase 3 承認なしでの変更実行
- Linear チケットの削除・アーカイブ
- Linear チケット description の直接書き換え（コンテキスト追加はコメント/attachment で行う）
- config.md の無断変更
- リライト原則・用語対応表を無視した顧客向け文書の生成

**必須事項:**
- Phase 0 での config バリデーション
- Phase 1 の前に `linear` CLI の利用可能性確認
- Phase 3 でのユーザー承認ゲート
- Phase 4 Step 3 での Document レビューゲート
- Phase 5 での検証
- 全ての外部リンクを Linear スキャンから収集（Linear 外の探索は行わない）

## Artifacts

| ファイル | 書き込みフェーズ | 用途 |
|---------|----------------|------|
| `.weekly-sync/config.md` | Phase 0 (ウィザード) | プロジェクト固有設定（永続） |
| `.weekly-sync/scan.json` | Phase 1 | スキャン結果（Phase 5 でクリーンアップ） |
| `.weekly-sync/sync-plan.json` | Phase 2 | 同期計画（Phase 5 でクリーンアップ） |
