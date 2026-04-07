# 実行レポート

Step 5 (Execute) で生成する `.linear-refresh/result.json` のフォーマット。

## JSON 構造

```json
{
  "cleanup": {
    "success": 0,
    "failed": 0,
    "failures": [
      {
        "ticket_id": "ISSUE-XX",
        "action": "親設定",
        "error": "理由"
      }
    ]
  },
  "add": {
    "created": 0,
    "linked": 0,
    "failed": 0,
    "failures": [
      {
        "item": "説明",
        "action": "create",
        "error": "理由"
      }
    ]
  },
  "changes": [
    {
      "ticket_id": "ISSUE-XX",
      "type": "cleanup | create | link",
      "description": "変更内容"
    }
  ]
}
```

## 実行順序

1. **Cleanup**（厳密な順序）:
   1. 親子関係の設定
   2. 並列: blockedBy、relatedTo、ステータス変更、プロジェクト紐付け、コンテキスト追加
   3. 重複統合（Done + duplicateOf に設定）

2. **Add**（厳密な順序）:
   1. 新規チケット作成
   2. 既存チケットへのリンク（コメント/attachment）

## エラーハンドリング

| エラー | 対応 |
|-------|------|
| Linear API エラー（個別チケット） | スキップして続行。failures リストに追加 |
| Linear API レート制限 | 待機してリトライ（最大3回） |
| チケットが既に削除/アーカイブ済み | スキップして failures リストに追加 |
| 親子関係の循環参照 | スキップして failures リストに追加 |
| Cleanup の失敗 | Add の実行をブロック**しない** |

## 表示フォーマット

実行後、結果をユーザーに提示する:

```
## Refresh Result

### Cleanup
✓ 成功: N件
✗ 失敗: N件
- ISSUE-XX: 親設定失敗 (理由)

### Add
✓ 作成: Nチケット
✓ リンク: Nチケット
✗ 失敗: N件
- #XX: 作成失敗 (理由)

### 変更されたチケット一覧
| チケット | 種別 | 変更内容 |
|---------|------|---------|
| ISSUE-XX | cleanup | ISSUE-YY を親に設定 |
```
