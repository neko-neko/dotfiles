# Linear API Notes

linear-sync supplement で使用する Linear MCP ツールの制約・注意事項。

## 使用ツール一覧

| ツール | 用途 |
|-------|------|
| `get_authenticated_user` | 現在ユーザー取得（resolve_ticket のフォールバック） |
| `get_issue` | チケット詳細取得（存在確認、チーム特定） |
| `list_issues` | アサイン済みチケット検索（resolve_ticket のフォールバック） |
| `list_issue_statuses` | ステータス一覧取得（In Progress / Done の特定） |
| `save_issue` | チケット更新（ステータス変更） |
| `save_comment` | コメント作成/更新（フェーズログ） |
| `list_comments` | コメント一覧取得（冪等性チェック） |
| `create_attachment` | ファイルアップロード（エビデンス） |
| `create_document` | Document 作成（ワークフローレポート） |
| `update_document` | Document 更新（フェーズ進捗反映） |

## 制約事項

### create_attachment
- `base64Content`: Base64 エンコード済み文字列。バイナリファイルは Bash の `base64 -i {path}` でエンコード
- サイズ制限: Linear の制限に依存（公式ドキュメント未明記）。大きいファイルでアップロード失敗する場合あり
- contentType は正確に指定すること（image/png, application/json, text/markdown 等）

### save_issue
- `links` パラメータは**追記のみ**。既存リンクの削除はできない
- `state` はステータス名または ID を指定。`list_issue_statuses` で事前に取得したものを使用する

### save_comment
- `id` を指定すると既存コメントを更新。省略すると新規作成
- `body` は Markdown 形式

### create_document
- `issue` パラメータでチケットに紐づけ可能
- 返却される ID を保持して `update_document` で更新に使用する

### ステータスの特定方法
`list_issue_statuses` の結果から type フィールドで判定:
- "In Progress" 相当: `type: "started"` のステータス
- "Done" 相当: `type: "completed"` のステータス

## エラーハンドリング方針

全 API 呼び出しで失敗時はワークフローをブロックしない。
詳細は SKILL.md の Error Handling セクションを参照。
