---
name: linear-refresh
description: >-
  Linear チケットの棚卸し・構造整理・未登録ソース発見を
  Collect/Discover/Analyze/Approve/Execute の 5 ステップで一気通貫実行する。
  既存の外部リンク探索に加え、Slack/GitHub のキーワード検索と逆引きで未紐付きの
  外部ソースも発見する。定期的な Linear メンテナンス、または「棚卸し」「リフレッシュ」
  「整理」の依頼時に使用する。
argument-hint: "[--force] [--skip-discovery] [--cleanup-only] [--add-only]"
---

# Linear Refresh

Linearチームのチケット棚卸し・構造整理・新規検出を一気通貫で実行する。

## Options

| Option | 効果 |
|--------|------|
| `--force` | Step 4 (Approve) をスキップ — Plan は表示するが即座に実行 |
| `--skip-discovery` | Step 2 (Discover) をスキップ — リンク済みソースのみ対象 |
| `--cleanup-only` | Step 3 の add 分析をスキップ |
| `--add-only` | Step 3 の cleanup 分析をスキップ |

## Prerequisites

- `linear` CLI が利用可能であること: `which linear && linear --version`
- `/slackcli` スキルが利用可能であること（Slack 探索用）
- チーム選択: `linear team list` → 1チーム: 自動選択 / 複数: ユーザーに選択を求める / 0: エラー終了

## Workflow

```
Step 1: Collect    — チケット取得 + リンク済みURLの探索
Step 2: Discover   — キーワード検索 + チケット逆引き（--skip-discovery で省略）
Step 3: Analyze    — Cleanup + Add 分析を一括実行
Step 4: Approve    — 統合Planをユーザーに提示して承認を得る（--force で省略）
Step 5: Execute    — Linear API で変更を適用
```

**開始時アナウンス:** 「Linear Refresh を開始します。Step 1: Collect」

## Step 1: Collect

チケットを全件取得し、description/attachments からリンクされた外部ソースを探索する。

1. `/linear-cli` と `/slackcli` スキルを invoke する。
2. チケット一覧を取得: `linear issue list --team {id} --sort priority --all-states --all-assignees --limit 0 --no-pager`
3. アクティブチケットの詳細取得を**並列サブエージェント**でディスパッチ（10件バッチ）。
   → サブエージェント指示: [collect-agent.md](references/collect-agent.md) 「詳細取得エージェント」
4. 結果からURLを抽出。[external-source-exploration.md](references/external-source-exploration.md) に従って分類する。
5. 1ホップURL探索を**並列サブエージェント**でディスパッチ（チケットクラスタ単位）。
   → サブエージェント指示: [collect-agent.md](references/collect-agent.md) 「1ホップ探索エージェント」
6. 2ホップ条件を評価: In Progress + Urgent/High + 72時間以内のアクティビティ。
7. 該当URLがあれば、2ホップ探索を**並列サブエージェント**でディスパッチ。
   → サブエージェント指示: [collect-agent.md](references/collect-agent.md) 「2ホップ探索エージェント」
8. 全結果を [collected-context-schema.md](references/collected-context-schema.md) に従って `.linear-refresh/collected-context.json` にマージ。

## Step 2: Discover

チケットからリンクされていない外部ソースを、キーワード検索とチケット逆引きで発見する。

**`--skip-discovery` 指定時はスキップ。** 空の `discovery_sources: []` を書き込んで次へ進む。

1. collected-context.json から [discovery-strategy.md](references/discovery-strategy.md) に従ってクエリシードを生成する。
2. Slack検索とGitHub検索を**並列サブエージェント**でディスパッチ。
   → サブエージェント指示: [discover-agent.md](references/discover-agent.md)
3. 結果をフィルタリング: Step 1 のソースと重複排除し、無関係なものを除外。
4. `.linear-refresh/collected-context.json` に `discovery_sources[]` として追記。

## Step 3: Analyze

Cleanup と Add の分析を一括実行する。collected-context.json を1回読み込む。

1. [cleanup-guidelines.md](references/cleanup-guidelines.md) を参照。8カテゴリで変更候補を検出する。
   **`--add-only` 指定時はスキップ。**
2. [add-guidelines.md](references/add-guidelines.md) を参照。`create`/`link`/`skip` の disposition で検出項目を判定する。
   重複排除のため cleanup 結果を参照する。
   **`--cleanup-only` 指定時はスキップ。**
3. `discovery_sources` の項目: 同じ分析を適用するが、根拠に `[discovered]` タグを付与する。
4. **セルフチェック:**
   - すべての In Progress チケットが少なくとも1回分析されたか。
   - discovery_sources の deferred signals が Plan に反映されているか。
   - external_sources + discovery_sources の両方が 0 件だがチケットにURLがある場合、異常としてユーザーに報告。
5. `.linear-refresh/plan.json` を書き出す。

## Step 4: Approve

統合 Plan をユーザーに提示して承認を得る。

**`--force` 指定時はスキップ**（Plan は表示するが承認待ちしない）。

表示フォーマット:

```
## Linear Refresh Plan

**Team:** {team_id} ({total_tickets} tickets, {external_sources} linked, {discovery_sources} discovered)

### Cleanup ({N} items)
（カテゴリ別にグループ化: 親子関係、関連、ブロック、ステータス、プロジェクト、コンテキスト、タイトル、期限、重複。空カテゴリは省略。）

### Add ({N} items)
（disposition 別にグループ化: create, link, skip。）

---
Approve? (ok / modify / cancel)
```

- `ok` → Step 5 へ
- ID指定で修正指示 → plan.json を更新し、再提示
- `cancel` → 終了

## Step 5: Execute

承認済み Plan を Linear API で適用する。

1. **Cleanup**（厳密な順序）:
   a. 親子関係の設定（順次実行）
   b. 並列: blockedBy、relatedTo、ステータス変更、プロジェクト紐付け、コンテキスト追加、タイトル変更、期限設定
   c. 重複統合 — Done + duplicateOf（順次実行、最後に実行）
2. **Add**（厳密な順序）:
   a. 新規チケット作成
   b. 既存チケットへのリンク（コメント + relation/attachment）
3. エラーハンドリング: 個別失敗はスキップして続行、レート制限はリトライ（最大3回）、Cleanup 失敗は Add をブロックしない。
   → 結果フォーマット: [execution-report.md](references/execution-report.md)
4. `.linear-refresh/result.json` を書き出し、結果サマリーを表示する。

## Red Flags

**禁止事項:**
- 承認済み Plan なしでの変更実行（`--force` 時を除く）
- チケットの削除・アーカイブ（Cleanup は重複を Close するのみ）
- チケット description の書き換え（コンテキスト追加はコメント/attachment で行う）
- Step 1 での2ホップ超の探索（無限展開防止）
- Step 2 での30日超の検索

**必須事項:**
- Step 1 の前に `/linear-cli` と `/slackcli` を invoke
- 要約予算の遵守（優先度別 200/400/800文字）
- 外部ソースからの deferred signals の記録
- discovery 由来の項目には根拠に `[discovered]` タグを付与
- すべての実行失敗を result JSON に記録

## Artifacts

| ファイル | 書き込みステップ | 用途 |
|---------|----------------|------|
| `.linear-refresh/collected-context.json` | Step 1 + Step 2 | 全チケット、リンク済みソース、発見ソース |
| `.linear-refresh/plan.json` | Step 3 | 統合 Cleanup + Add Plan |
| `.linear-refresh/result.json` | Step 5 | 実行結果 |
