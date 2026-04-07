# CollectedContext スキーマ

Step 1 (Collect) で生成し、Step 2 (Discover) で拡張される `.linear-refresh/collected-context.json` の JSON スキーマ。

## 構造

```json
{
  "team_id": "string",
  "tickets": [],
  "external_sources": [],
  "discovery_sources": []
}
```

## tickets[]

各チケットエントリの内容:

| フィールド | 型 | 説明 |
|-----------|---|------|
| `id` | string | Linear Issue 識別子（例: "RAKMY-20"） |
| `title` | string | Issue タイトル |
| `status` | string | 現在のステータス（Backlog, Todo, In Progress, Done, Cancelled） |
| `priority` | string | 優先度（Urgent, High, Medium, Low, No priority） |
| `labels` | string[] | ラベル名 |
| `project` | string \| null | 紐付いたプロジェクト名 |
| `parentId` | string \| null | 親 Issue ID |
| `assignee` | string \| null | 担当者名 |
| `completedAt` | string \| null | ISO 8601 完了日時 |
| `archivedAt` | string \| null | ISO 8601 アーカイブ日時 |
| `attachments` | object[] | `[{ "url": "string", "title": "string" }]` |
| `description_urls` | string[] | description から `https?://[^\s)]+` で抽出したURL |
| `relations` | object | `{ "relatedTo": [], "blocks": [], "blockedBy": [] }` |

## external_sources[]

チケットURL経由で発見されたソース（Step 1）。各エントリ:

| フィールド | 型 | 説明 |
|-----------|---|------|
| `url` | string | 探索したURL |
| `ticket_id` | string | 参照元チケットID |
| `hop` | number | 1 = チケットURLから直接, 2 = 1ホップの referenced_urls から |
| `accessible` | boolean | URLの取得に成功したか |
| `summary` | string | コンテンツ要約（予算: 優先度別 200/400/800文字） |
| `referenced_urls` | string[] | 取得コンテンツ内で言及されたURL |
| `latest_activity_ts` | string | ISO 8601 最終アクティビティ日時 |
| `deferred_signals` | string[] | 検出された deferred commitment パターン |
| `source_type` | string | slack_thread, github_issue, github_pr, github_comment, document のいずれか |

## discovery_sources[]

キーワード検索・チケット逆引きで発見されたソース（Step 2）。
external_sources とは出所と信頼度が異なるため分離している。

| フィールド | 型 | 説明 |
|-----------|---|------|
| `url` | string | 発見したURL |
| `discovery_query` | string | このソースを見つけた検索クエリ |
| `related_tickets` | string[] | 関連すると判断されたチケットID |
| `accessible` | boolean | URLの取得に成功したか |
| `summary` | string | コンテンツ要約（予算は external-source-exploration.md に従う） |
| `latest_activity_ts` | string | ISO 8601 最終アクティビティ日時 |
| `deferred_signals` | string[] | 検出された deferred commitment パターン |
| `source_type` | string | slack_message, slack_thread, github_issue, github_pr のいずれか |
