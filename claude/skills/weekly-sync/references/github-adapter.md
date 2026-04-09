# GitHub Project アダプタ

`output_adapter: github` 時に使用する。GitHub CLI (`gh`) を使用。

## 前提

- `gh` CLI がインストール・認証済み
- config に `github.org`, `github.repo`, `github.project_number`, `github.user` が設定済み

## scan_existing

出力先の既存アイテム一覧を取得する。

```bash
gh project item-list {project_number} --owner {org} --format json
```

各アイテムから抽出:
- `output_id`: GitHub Issue 番号（`content.number`）
- `title`: アイテムタイトル
- `status`: Project のステータスフィールド値
- `linear_id`: Linear ID カスタムフィールド値
- `fields`: 全カスタムフィールド

## scan_new_external

期間内に `github.user` 以外が作成した Issue を検索する。

```bash
gh issue list --repo {repo} \
  --state all \
  --search "created:>{from_date} -author:{user}" \
  --json number,title,author,state,createdAt,labels \
  --limit 50
```

`scan_existing` の結果と照合し、Project に未登録のものを抽出。

## create_item

新規 GitHub Issue を作成する。

```bash
gh issue create --repo {repo} \
  --title "{customer_facing_title}" \
  --label "{labels}" \
  --body "{body}"
```

ラベルは config の `label_mapping` を逆引きして設定。

## update_item

既存 Issue の title/body を更新する。

```bash
gh issue edit {number} --repo {repo} \
  --title "{title}" \
  --body "{body}" \
  [--add-label "{labels}"]
```

## add_comment

Issue にコメントを追加する。

```bash
gh issue comment {number} --repo {repo} --body "{body}"
```

## add_to_board

Issue を Project に追加し、カスタムフィールドを設定する。

### Step 1: Project ID とフィールド情報取得

```bash
PROJECT_ID=$(gh project view {project_number} --owner {org} --format json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

gh project field-list {project_number} --owner {org} --format json
```

フィールド ID とオプション ID を記録。

### Step 2: アイテム追加

```bash
gh project item-add {project_number} --owner {org} --url "https://github.com/{repo}/issues/{number}"
```

返される item ID を記録。

### Step 3: フィールド設定

config の `custom_fields` 定義に基づいて各フィールドを設定:

```bash
# Single Select フィールド
gh project item-edit --project-id {project_id} --id {item_id} \
  --field-id {field_id} --single-select-option-id {option_id}

# Text フィールド
gh project item-edit --project-id {project_id} --id {item_id} \
  --field-id {field_id} --text "{value}"
```

## update_status

Project 上のアイテムのステータスを更新する。

```bash
gh project item-edit --project-id {project_id} --id {item_id} \
  --field-id {status_field_id} --single-select-option-id {status_option_id}
```

ステータスオプション ID はフィールド情報から `status_mapping` の値に一致するものを探す。

## アイテム ID の特定

既存アイテムの item ID を特定するには GraphQL を使用:

```bash
gh api graphql -f query='
query {
  organization(login: "{org}") {
    projectV2(number: {project_number}) {
      items(first: 100) {
        nodes {
          id
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } }
            }
          }
        }
      }
    }
  }
}
'
```

Linear ID フィールドの値でマッチングして item ID を特定する。
