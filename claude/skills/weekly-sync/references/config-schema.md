# config.md スキーマ定義

`.weekly-sync/config.md` の YAML frontmatter フィールド定義。

## 必須フィールド

| フィールド | 型 | 説明 |
|-----------|---|------|
| `linear_team` | string | Linear チーム ID |
| `linear_workspace` | string | Linear workspace slug |
| `output_adapter` | string | 出力先アダプタ名（`github` \| `notion` \| `gdocs`） |
| `status_mapping` | map | Linear ステータス → 出力先ステータスのマッピング（6キー必須） |
| `rewrite_principles` | string (multiline) | 顧客向けリライト原則 |
| `document_prefix` | string | 定例 Document のプレフィックス |
| `baseline_prefix` | string | ベースライン Document のプレフィックス |

## アダプタ固有フィールド（`output_adapter` に応じて必須）

### github

| フィールド | 型 | 説明 |
|-----------|---|------|
| `github.org` | string | GitHub Organization 名 |
| `github.repo` | string | リポジトリ（`{org}/{repo}` 形式） |
| `github.project_number` | integer | GitHub Project 番号 |
| `github.user` | string | スキャンから除外する GitHub ユーザー名 |

## オプションフィールド

| フィールド | 型 | 説明 | デフォルト |
|-----------|---|------|----------|
| `label_mapping` | map | Linear ラベル → 出力先ラベルのマッピング | (空) |
| `custom_fields` | list | 出力先のカスタムフィールド定義 | (空) |
| `terminology` | map | 技術用語 → 顧客向け表現の対応表 | (空) |

## custom_fields 要素

| フィールド | 型 | 説明 |
|-----------|---|------|
| `name` | string | 出力先でのフィールド名 |
| `type` | string | `single_select` \| `text` |
| `source` | string | Linear 側のデータソース: `label` \| `priority` \| `identifier` \| `manual` |
| `mapping` | map | `source: manual` 時のマッピング定義 |

## バリデーションルール

1. `status_mapping` は Linear の6ステータス（Backlog, Todo, In Progress, In Review, Done, Canceled）すべてにキーが必要
2. `output_adapter` が `github` の場合、`github` セクションの全フィールドが必須
3. `rewrite_principles` が空の場合はバリデーションエラー（意図的な省略を防ぐ）
4. `document_prefix` と `baseline_prefix` は異なる値であること

## body セクション

YAML frontmatter の後に Markdown body を記述可能。
ウィザードでは表現しきれないプロジェクト固有の補足事項を自由記述する。
スキルはこの body をサブエージェントへの追加コンテキストとして渡す。
