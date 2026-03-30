---
name: linear-cleanup
description: >-
  Linearチームのチケットを棚卸し・構造整理するスキル。
  チケットに紐付いた外部リンク（Slack、GitHub等）を自動探索し、
  親子関係・ブロック関係・ステータス不整合・重複・コンテキスト不足を検出して一括修正する。
  --force 指定時は承認ステップをスキップする。
user-invocable: true
---

# Linear Cleanup

Linearチームのチケット棚卸しスキル。Linearを Single Source of Truth とし、外部リンクを入力データソースとして探索・分析し、構造整理を一気通貫で実行する。

**開始時アナウンス:** 「Linear Cleanup を開始します。Phase 1: Collect」

## Options

- `--force` — 変更計画の承認ステップをスキップ（変更計画は表示する）

## Prerequisites

- Linear MCP が利用可能であること（`mcp__plugin_linear_linear__*` ツール群）
- チームが1つ以上存在すること

起動時に `mcp__plugin_linear_linear__list_teams` を呼び出し:
- チームが1つ → 自動選択
- チームが複数 → 一覧を提示して選択を求める
- チームが0 → エラー終了

## Phase 1: Collect

### Step 1-1: Linearチケット全件取得

`mcp__plugin_linear_linear__list_issues` を `team` パラメータ指定・`limit: 250` で呼び出す。250件を超える場合は `cursor` で全件取得する。

取得した各チケットについて以下を記録:
- id, title, status, priority, labels, project, parentId, assignee
- completedAt, archivedAt
- attachments (URL + title)
- description 内の URL（正規表現 `https?://[^\s\)]+` で抽出）

### Step 1-2: 主要チケットの詳細取得

status が Done/Cancelled 以外のチケット、および直近30日以内に更新されたチケットについて `mcp__plugin_linear_linear__get_issue` で詳細を取得する。これにより relatedTo, blocks, blockedBy 等の既存 relation 情報を得る。

Agent tool を使い、チケット数に応じて並列で詳細取得する（10件ずつバッチ等）。

### Step 1-3: 外部リンクの探索

Step 1-1, 1-2 で収集した全 URL を統合し、オーケストレーターが以下の基準でフィルタリングする:

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

## Phase 2: Merge + Analyze

Phase 1 の全エージェント結果を統合し、以下の分析ガイドラインに基づいて変更候補を検出する。

各ガイドラインはヒューリスティックであり、最終判断はコンテキスト理解に基づく。機械的なルール適用ではなく、チケット群の全体像を把握した上で判断する。

### 分析ガイドライン

#### 親子関係の検出

| シグナル | 判定 |
|---|---|
| description に「親チケット」「Epic」等の記述がある | 記述先を parent 候補に |
| 同一機能領域で Feature/Epic + Bug/Improvement の組み合わせ | Feature/Epic を parent 候補に |
| 同一 PR を参照する複数チケットで、片方がもう片方のスコープを包含 | 包含する側を parent 候補に |
| タイトルに Phase N / Step N が含まれる複数チケット | 共通の親を推定 |

#### ブロック関係の検出

| シグナル | 判定 |
|---|---|
| description に「〜の完了待ち」「〜がブロッカー」等の記述 | blockedBy 候補 |
| 外部ソースの会話で「〜のリリース後に」という合意 | blockedBy 候補 |
| description に同一環境の競合が記述されている | blockedBy 候補 |

#### 関連（relatedTo）の検出

| シグナル | 判定 |
|---|---|
| description に他チケットへの言及があるが relation 未設定 | relatedTo 候補 |
| 同一の外部ソーススレッドで議論されている複数チケット | relatedTo 候補 |
| 原因 → 対策、事象 → 修正 の因果関係がある | relatedTo 候補 |

#### ステータス不整合の検出

| パターン | 判定 |
|---|---|
| archived だが completedAt が null | 不整合 → Done または unarchive |
| In Progress だが参照 PR/Issue が全て存在し全て closed | Done 候補 |
| In Progress だが blockedBy の依存先が未解決 | Blocked として報告 |
| 未完了だが外部ソースでリリース完了の明確な報告がある | Done 候補 |
| Done だが参照 PR が open のまま | 不整合として報告 |

#### 重複チケットの検出

| シグナル | 判定 |
|---|---|
| 同一 PR/Issue を参照し、かつスコープが同一 | 統合候補 |
| 同一の機能・バグ・要望を別の角度から記述している | 統合候補（ユーザー判断を仰ぐ） |

#### コンテキスト不足の検出

| パターン | 判定 |
|---|---|
| description に外部 URL の言及があるが attachments に未登録 | リンク追加候補 |
| 外部ソースで該当チケットの話題があるが紐付けなし | リンク追加候補 |
| project 未設定だが、同一ラベルの他チケットが特定プロジェクトに所属 | プロジェクト設定候補 |

## Phase 3: Plan + Approve

Phase 2 の分析結果を以下のフォーマットで変更計画として提示する。

### 変更計画フォーマット

変更がないカテゴリは省略する。

```markdown
## Linear Cleanup Plan

### Summary
- 対象チケット: N件
- 検出された変更: N件
- 外部ソース探索: N件（探索成功 / スキップ / 失敗の内訳）

### 1. 親子関係 (N件)
| 親 | 子 | 根拠 |
|---|---|---|

### 2. ブロック関係 (N件)
| チケット | blockedBy | 根拠 |
|---|---|---|

### 3. 関連 (N件)
| チケット | relatedTo | 根拠 |
|---|---|---|

### 4. ステータス変更 (N件)
| チケット | 現在 | 変更先 | 根拠 |
|---|---|---|---|

### 5. 重複統合 (N件)
| 統合先 | 統合元(close) | 根拠 |
|---|---|---|

### 6. コンテキスト追加 (N件)
| チケット | 追加内容 | ソース |
|---|---|---|
```

### 承認フロー

- 通常モード: 変更計画を提示し、ユーザーの承認を待つ。ユーザーは以下のいずれかで応答:
  - 「ok」「承認」等 → Phase 4 へ進む
  - チケットIDを指定して修正指示 → 変更計画を修正して再提示
  - 「キャンセル」等 → 終了
- `--force` モード: 変更計画を表示するが承認待ちをスキップし、直ちに Phase 4 へ進む

## Phase 4: Execute

承認された変更計画を Linear API で実行する。

### 実行順序

依存関係を考慮した3段階実行:

1. **親子関係の設定**（`save_issue` の `parentId`）— 先に実行。他の relation の前提になりうる
2. **以下を並列実行:**
   - blockedBy 設定（`save_issue` の `blockedBy`）
   - relatedTo 設定（`save_issue` の `relatedTo`）
   - ステータス変更（`save_issue` の `state`）
   - プロジェクト紐付け（`save_issue` の `project`）
   - コンテキスト追加（`save_issue` の `links`）
3. **重複統合**（`save_issue` の `state: Done` + `duplicateOf`）— 最後に実行。他の変更が完了してから

### エラーハンドリング

| エラー | 対応 |
|---|---|
| Linear API エラー（個別チケット） | スキップして続行。失敗一覧に追加 |
| Linear API レート制限 | 待機してリトライ（最大3回） |
| チケットが既に削除/アーカイブ済み | スキップして失敗一覧に追加 |
| 親子設定で循環参照が発生 | スキップして失敗一覧に追加 |

### 実行結果レポート

実行完了後、以下のフォーマットで結果を出力する:

~~~markdown
## Execution Result

✓ 成功: N件
✗ 失敗: N件
- ISSUE-XX: parentId設定失敗 (reason)

### 変更されたチケット一覧
| チケット | 変更内容 |
|---|---|
~~~

## Scope Boundaries

### スキルが行うこと
- 既存チケットの構造整理（親子、blockedBy、relatedTo）
- ステータス不整合の修正
- コンテキスト追加（attachments/links のみ）
- 重複チケットの統合（close + duplicateOf）
- プロジェクト紐付け

### スキルが行わないこと
- チケットの新規作成
- チケットの削除（統合時も close であり delete ではない）
- description の書き換え
