# 出力アダプタ共通契約

すべての出力アダプタが実装すべき操作と、その入出力の契約。

## 操作一覧

### scan_existing

**目的:** 出力先の既存アイテム一覧を取得する。

**出力:**
```json
[
  {
    "output_id": "{identifier}",
    "title": "{title}",
    "status": "{status_label}",
    "linear_id": "{linear_identifier_or_null}",
    "fields": {}
  }
]
```

### scan_new_external

**目的:** 期間内に特定ユーザー以外が作成したアイテムを検索する。

**入力:** `from` (日時), 除外ユーザー情報

**出力:**
```json
[
  {
    "output_id": "{identifier}",
    "title": "{title}",
    "author": "{author}",
    "created_at": "{datetime}",
    "state": "{state}",
    "body_summary": "{summary}"
  }
]
```

### create_item

**目的:** 新規アイテムを作成する。

**入力:** title, body, labels

**出力:** 作成されたアイテムの output_id

### update_item

**目的:** 既存アイテムの title/body を更新する。

**入力:** output_id, title (optional), body (optional), labels (optional)

### add_comment

**目的:** アイテムにコメントを追加する。

**入力:** output_id, body

### add_to_board

**目的:** アイテムをボード/ビューに追加し、フィールドを設定する。

**入力:** output_id, status, custom_fields (key-value pairs)

### update_status

**目的:** ボード上のアイテムのステータスを更新する。

**入力:** output_id, new_status (出力先のステータスラベル)

## 新規アダプタ追加手順

1. `references/{adapter_name}-adapter.md` を作成
2. 上記7操作すべてを実装（該当しない操作は理由を記述して no-op）
3. config.md のアダプタ固有設定セクションのスキーマを定義
4. `config-schema.md` にアダプタ固有フィールドを追加
5. `setup-wizard.md` にアダプタ固有の設定ステップを追加
