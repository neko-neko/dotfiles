# 差分分析テンプレート

Phase 2 で生成する `.weekly-sync/sync-plan.json` のフォーマット。

## スキーマ

```json
{
  "period": {
    "from": "2026-04-03T17:30:00+09:00",
    "to": "2026-04-09"
  },
  "new": [
    {
      "linear_id": "{id}",
      "title": "{linear_title}",
      "customer_title": "{rewritten_title}",
      "status": "{linear_status}",
      "priority": 2,
      "labels": ["..."],
      "action": "create_output",
      "category": "{label_mapping_result}",
      "type": "{label_mapping_result}"
    }
  ],
  "new_external": [
    {
      "output_id": "{id}",
      "title": "{title}",
      "author": "{author}",
      "action": "create_linear",
      "proposed_linear_title": "{technical_title}",
      "proposed_status": "Todo"
    }
  ],
  "status_changes": [
    {
      "linear_id": "{id}",
      "output_id": "{output_id}",
      "from_status": "{current_output_status}",
      "to_status": "{mapped_linear_status}"
    }
  ],
  "context_updates": [
    {
      "linear_id": "{id}",
      "output_id": "{output_id}",
      "summary": "{human_readable_summary}",
      "external_links": [
        { "type": "Slack", "url": "...", "summary": "..." }
      ]
    }
  ],
  "ssot_updates": [
    {
      "linear_id": "{id}",
      "type": "status | comment | attachment",
      "proposal": "{description}",
      "reason": "{why}"
    }
  ],
  "sync_targets": ["{id}", "{id}", "..."]
}
```

## 分類ルール

### 新規追加（`new`）

- Linear に存在するが出力先の `existing_items` に `linear_id` が一致するアイテムがない
- Done/Canceled も含める（今回の報告で初出の場合、定例で報告する必要がある）
- `customer_title` は config の `rewrite_principles` と `terminology` を適用して生成

### 新規外部（`new_external`）

- 出力先の `new_external_items` のうち、Linear チケットが存在しないもの
- Linear チケットが既に存在する場合は `new` ではなくリンクのみ（`new` に `action: link_output` で追加）

### ステータス変更（`status_changes`）

- `existing_items` の各アイテムについて、対応する Linear チケットの `state` を `status_mapping` でマッピングした値と比較
- 不一致があれば記録

### コンテキスト更新（`context_updates`）

- `existing_items` のうち Done でないもので、対応する Linear チケットに `recent_comments` または `external_links` がある
- `summary` は顧客向けリライト原則を適用した1行要約

### SSOT 更新（`ssot_updates`）

- Linear スキャンの `ssot_proposal` が null でないもの

### 同期対象（`sync_targets`）

- 上記すべてのカテゴリに出現する Linear ID のユニーク一覧
- 定例 Document 作成の対象となる
