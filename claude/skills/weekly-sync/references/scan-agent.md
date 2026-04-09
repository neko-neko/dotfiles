# Scan Agent 指示

Phase 1 で並列ディスパッチされるサブエージェント向け指示。

## Agent A: Linear スキャン

### 入力

- `linear_team`: Linear チーム ID
- `from`: 同期対象期間の開始日時（ISO 8601）

### 手順

1. 期間内に更新されたチケットを取得:

```bash
linear issue list --team {linear_team} --all-states --updated-after {from} --limit 0 --json --no-pager
```

2. 各チケットの詳細を取得:

```bash
linear issue view {identifier} --json --no-pager
```

3. 各チケットについて以下を記録:
   - `identifier`: チケット ID
   - `title`: タイトル
   - `state`: 現在のステータス
   - `priority`: 優先度（1=Urgent, 2=High, 3=Medium, 4=Low）
   - `labels`: ラベル一覧
   - `description_summary`: description の要約（3行以内）
   - `external_links`: 外部リンク一覧（種別, URL, 概要）
     - description, コメント, attachment のすべてから収集
     - 種別: Slack, Google Sheets, Google Drive, GitHub PR, GitHub Issue, Bugsnag, 外部サイト 等
   - `recent_comments`: `{from}` 以降のコメント（author, body要約, 日時）
   - `ssot_proposal`: SSOT 更新が必要と判断した場合の提案（null or object）

4. SSOT 更新の判断基準:
   - ステータスが実態と合っていない（例: GitHub PR がマージ済みなのに In Progress）
   - 重要な外部リンクがコメントにはあるが attachment に未登録
   - description が現状を反映していない

   **提案のみ記録し、実際の更新は行わない。**

### 出力

```json
{
  "updated_tickets": [
    {
      "identifier": "...",
      "title": "...",
      "state": "...",
      "priority": 2,
      "labels": ["..."],
      "description_summary": "...",
      "external_links": [
        { "type": "Slack", "url": "...", "summary": "..." }
      ],
      "recent_comments": [
        { "author": "...", "body_summary": "...", "date": "..." }
      ],
      "ssot_proposal": null
    }
  ]
}
```

---

## Agent B: 出力先スキャン

### 入力

- アダプタ仕様ファイル（`references/{adapter}-adapter.md`）
- アダプタ固有の config 値
- `from`: 同期対象期間の開始日時
- `github.user`: 除外するユーザー名（GitHub アダプタの場合）

### 手順

アダプタ仕様ファイルの `scan_existing` と `scan_new_external` セクションに従って実行する。

### 出力

```json
{
  "existing_items": [
    {
      "output_id": "#1234",
      "title": "...",
      "status": "...",
      "linear_id": "...",
      "fields": {}
    }
  ],
  "new_external_items": [
    {
      "output_id": "#5678",
      "title": "...",
      "author": "...",
      "created_at": "...",
      "state": "...",
      "body_summary": "..."
    }
  ]
}
```
