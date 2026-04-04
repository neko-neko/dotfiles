---
name: linear-refresh
description: >-
  linear-cleanup → linear-add を統合実行するワークフロー。
  外部ソース探索を1回で行い、cleanup分析 → add分析 → 統合Plan → 承認 → 実行を一気通貫で実行する。
  --force 指定時は承認ステップをスキップする。
user-invocable: true
---

# Linear Refresh

linear-cleanup と linear-add を統合実行するワークフロー。外部ソース探索を1回で行い、既存チケットの構造整理と新規チケットの検出・作成を一気通貫で実行する。
**`linear-cli` と `slackcli` を最初に必ずinvokeすること。**

**開始時アナウンス:** 「Linear Refresh を開始します。Phase 0: Collect」

## Options

- `--force` — 統合 Plan の承認ステップをスキップ（Plan は表示する）

## Prerequisites

- `linear` CLI が利用可能であること
- チームが1つ以上存在すること

起動時にチーム一覧を取得し:
- チームが1つ → 自動選択
- チームが複数 → 一覧を提示して選択を求める
- チームが0 → エラー終了

## Phase 0: Collect

**アナウンス:** 「Phase 0: Collect — チケットと外部ソースを収集します」

### Step 0-1: Linearチケット全件取得

チーム指定でチケットを全件取得する。

取得した各チケットについて以下を記録:
- id, title, status, priority, labels, project, parentId, assignee
- completedAt, archivedAt
- attachments (URL + title)
- description 内の URL（正規表現 `https?://[^\s\)]+` で抽出）

### Step 0-2: 主要チケットの詳細取得

status が Done/Cancelled 以外のチケット、および直近30日以内に更新されたチケットについて詳細を取得する。これにより relatedTo, blocks, blockedBy 等の既存 relation 情報を得る。

Agent tool を使い、チケット数に応じて並列で詳細取得する（10件ずつバッチ等）。

### Step 0-3: 外部リンクの探索

Step 0-1, 0-2 で収集した全 URL を統合し、以下の基準でフィルタリングする:

**探索する（有用性が高い）:**
- 会話の文脈を含むもの（Slackスレッド等）— 合意事項・ブロック状況の情報源

**メタデータのみ取得:**
- 静的ドキュメント（Google Sheets、Notion等）— タイトル・アクセス可否の確認のみ

**スキップ:**
- 画像ファイル、スクリーンショット
- 既に attachments として登録済みのリンク（description 内の URL と attachments の突合）

フィルタリング後の URL に対して Agent tool で並列探索を実行:
- 各エージェントには URL とチケットのコンテキスト（タイトル、description の要約）を渡す
- エージェントは利用可能なスキル/ツールでアクセスを試行し、不可能な場合は WebFetch でフォールバックする
- 戻り値: URL、取得成否、コンテキスト要約（200字以内）

### Step 0-4: CollectedContext 生成

全収集データを以下の構造に統合する:

```
CollectedContext:
  team_id: string
  tickets:
    - id, title, status, priority, labels, project, parentId, assignee
    - completedAt, archivedAt
    - attachments: [{url, title}]
    - description_urls: [string]
    - relations: {relatedTo, blocks, blockedBy}
  external_sources:
    - url: string
    - ticket_id: string          # 参照元チケット
    - accessible: boolean
    - summary: string            # 200字以内のコンテキスト要約
    - source_type: string        # slack_thread, github_issue, github_pr, document, etc.
```

## Phase 1: Cleanup 分析

**アナウンス:** 「Phase 1: Cleanup Analysis — 既存チケットの構造を分析します」

linear-cleanup の SKILL.md を Read し、Phase 2 (Merge + Analyze) の分析ガイドラインに従って CollectedContext を分析する。

cleanup の分析ガイドラインは以下の観点で変更候補を検出する:
- 親子関係
- ブロック関係
- 関連（relatedTo）
- ステータス不整合
- 重複チケット
- コンテキスト不足

出力: **Plan A**（cleanup の変更候補リスト。cleanup の Phase 3 フォーマット準拠）

## Phase 2: Add 分析

**アナウンス:** 「Phase 2: Add Analysis — 新規チケット候補を検出します」

linear-add の SKILL.md を Read し、Phase 2 (Analyze) の検出基準に従って CollectedContext を分析する。

Plan A で計画済みの変更と重複する項目は除外する。

出力: **Plan B**（add の検出項目リスト。add の Phase 3 フォーマット準拠）

## Phase 3: 統合 Plan + Approve

**アナウンス:** 「Phase 3: Plan — 変更計画を提示します」

Plan A と Plan B を1つのドキュメントにまとめて提示する。変更がないセクションは省略する。

### 統合 Plan フォーマット

~~~markdown
## Linear Refresh Plan

### Summary
- 対象チケット: N件
- Cleanup 変更: N件
- Add 検出: N件（create: N / link: N / skip: N）
- 外部ソース探索: N件（成功 / スキップ / 失敗の内訳）

### Cleanup
[cleanup の Plan フォーマット — 親子関係、ブロック関係、関連、ステータス変更、重複統合、コンテキスト追加]

### Add
[add の Plan フォーマット — Items テーブル with disposition]
~~~

### 承認フロー

- 通常モード: 統合 Plan を提示し、ユーザーの承認を待つ。ユーザーは以下のいずれかで応答:
  - 「ok」「承認」等 → Phase 4 へ進む
  - セクション名（Cleanup/Add）+ 項目を指定して修正指示 → 該当部分を修正して再提示
  - 「キャンセル」等 → 終了
- `--force` モード: 統合 Plan を表示するが承認待ちをスキップし、直ちに Phase 4 へ進む

## Phase 4: Execute

**アナウンス:** 「Phase 4: Execute — 変更を実行します」

### 実行順序

1. **Cleanup 変更**（cleanup の実行順序に従う）:
   1. 親子関係の設定
   2. 以下を並列実行: blockedBy 設定、relatedTo 設定、ステータス変更、プロジェクト紐付け、コンテキスト追加
   3. 重複統合（Done + duplicateOf）
2. **Add 実行**:
   1. create（新規チケット作成）
   2. link（既存チケットへの紐付け）

### エラーハンドリング

| エラー | 対応 |
|---|---|
| Linear API エラー（個別チケット） | スキップして続行。失敗一覧に追加 |
| Linear API レート制限 | 待機してリトライ（最大3回） |
| チケットが既に削除/アーカイブ済み | スキップして失敗一覧に追加 |
| 親子設定で循環参照が発生 | スキップして失敗一覧に追加 |
| Cleanup 実行の失敗 | 失敗分を除外して Add を続行。Cleanup 全体の失敗は Add をブロックしない |

### 実行結果レポート

~~~markdown
## Refresh Result

### Cleanup
✓ 成功: N件
✗ 失敗: N件
- ISSUE-XX: parentId設定失敗 (reason)

### Add
✓ create: N件
✓ link: N件
✗ 失敗: N件
- #XX: 作成失敗 (reason)

### 変更されたチケット一覧
| チケット | 種別 | 変更内容 |
|---|---|---|
~~~
