---
name: linear-add
description: >-
  外部ソースや既存チケットの分析から、注意を向ける価値のある項目を検出し、
  新規チケット作成・既存チケットへの紐付け・スキップを提案するスキル。
  --force 指定時は承認ステップをスキップする。
user-invocable: true
---

# Linear Add

外部ソースや既存チケットの分析から、注意を向ける価値のある項目を検出し、disposition（create / link / skip）を提案して実行するスキル。Linear を Single Source of Truth とし、未追跡の作業を Linear に登録する。

**開始時アナウンス:** 「Linear Add を開始します。Phase 1: Collect」

## Options

- `--force` — 変更計画の承認ステップをスキップ（変更計画は表示する）

## Prerequisites

- `linear` CLI が利用可能であること
- チームが1つ以上存在すること

起動時にチーム一覧を取得し:
- チームが1つ → 自動選択
- チームが複数 → 一覧を提示して選択を求める
- チームが0 → エラー終了

## Phase 1: Collect

### CollectedContext 入力（オプション）

linear-refresh 経由で起動された場合、CollectedContext が提供される。提供されている場合、Phase 1 の全ステップをスキップし、提供されたデータを使用して Phase 2 に進む。

CollectedContext が提供されていない場合（standalone 起動）、以下の Step 1-1 〜 1-3 を実行する。

### Step 1-1: Linearチケット全件取得

チーム指定でチケットを全件取得する。

取得した各チケットについて以下を記録:
- id, title, status, priority, labels, project, parentId, assignee
- completedAt, archivedAt
- attachments (URL + title)
- description 内の URL（正規表現 `https?://[^\s\)]+` で抽出）

### Step 1-2: 主要チケットの詳細取得

status が Done/Cancelled 以外のチケット、および直近30日以内に更新されたチケットについて詳細を取得する。これにより relatedTo, blocks, blockedBy 等の既存 relation 情報を得る。

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

## Phase 2: Analyze

CollectedContext を入力とし、注意を向ける価値のある項目を検出する。

cleanup の Plan（Plan A）が渡されている場合、Plan A で計画済みの変更と重複する項目は除外する。

### 入出力

- **入力**: CollectedContext + Plan A（オプション、linear-refresh 経由時のみ）
- **出力**: 検出項目リスト（Phase 3 の Plan フォーマット）

### 検出基準 — 「注意を向ける価値があるか」

各ガイドラインはヒューリスティックであり、最終判断はコンテキスト理解に基づく。機械的なルール適用ではなく、チケット群の全体像を把握した上で判断する。

検出の関心事は「未解決の義務があるか」または「介入の機会があるか」。

#### 明示的な義務

判断軸は「こちらにボールがあるか」。

| シグナル | 判定 |
|---|---|
| 外部ソースで作業が依頼・合意されているが、対応する Linear チケットが存在しない | 新規チケット候補 |
| 外部ソースで回答・対応を求められており、未応答のまま | 新規チケット候補 |
| 外部ソースで明確な next step が決まっているが、未追跡 | 新規チケット候補 |
| チケットの description/コメントで「次スプリントで」「フォローアップで」等の後続作業の言及 | フォローアップチケット候補 |

#### 介入の機会

こちらにボールがあるわけではないが、介入することで価値がある状況。

| シグナル | 判定 |
|---|---|
| 外部ソースの議論が停滞・空中戦化しており、提案を差し込むことで前進が見込める | 検出対象（disposition で判断） |
| 方向性が見えない会話が続いている | 検出対象（disposition で判断） |
| 決定権者不在で膠着している議論 | 検出対象（disposition で判断） |

#### 構造的ギャップ

| シグナル | 判定 |
|---|---|
| 親チケットの description に作業分解の記述があるが、対応する子チケットが不足 | 子チケット候補 |
| 「〜待ち」「〜の完了後に着手」の言及先に Linear チケットが存在しない | ブロッカーチケット候補 |

### 除外基準（検出対象外）

- 回答済みで完結している議論
- 結論が出ておらず、こちらにボールがない検討中の話題
- 既に対応済みの作業
- 既存チケットのスコープに含まれる作業（重複）

## Phase 3: Plan + Approve

Phase 2 の検出結果に対して、各項目に disposition を提案する。

### disposition

| disposition | 意味 | 実行時のアクション |
|---|---|---|
| **create** | 新規チケット作成 | title, description, priority, labels, parent, links を設定してチケット作成 |
| **link** | 既存チケットへの紐付け | コメント追加 + relation/attachment 設定 |
| **skip** | 対応不要 | 何もしない。理由を Plan に明記 |

### cleanup の「コンテキスト追加」との境界

cleanup は既存チケットに対して「参照されているが attachments 未登録のリンクを追加」する。add の `link` disposition は「新たに検出された外部議論を既存チケットに紐付ける」。

操作としては類似するが、トリガーが異なる:
- cleanup: チケットの description/コメントに既に URL があるが、attachments に未登録
- add: 外部ソース探索で検出された議論が、既存チケットのスコープに該当

refresh 経由時は Plan A（cleanup 計画）を参照することで重複を排除する。

### Plan フォーマット

~~~markdown
## Linear Add Plan

### Summary
- 検出された項目: N件
- create: N件 / link: N件 / skip: N件

### Items
| # | ソース | 要約 | disposition | 対象チケット | 根拠 |
|---|---|---|---|---|---|
~~~

### 承認フロー

- 通常モード: Plan を提示し、ユーザーの承認を待つ。ユーザーは以下のいずれかで応答:
  - 「ok」「承認」等 → Phase 4 へ進む
  - 項目番号を指定して disposition 変更指示 → Plan を修正して再提示
  - 「キャンセル」等 → 終了
- `--force` モード: Plan を表示するが承認待ちをスキップし、直ちに Phase 4 へ進む

## Phase 4: Execute

承認された Plan を Linear API で実行する。

### 実行順序

1. **create** — 新規チケットを先に作成。link 時に新規チケットへの relation を設定できるようにするため
2. **link** — 既存チケットへのコメント追加 + relation/attachment 設定

### エラーハンドリング

| エラー | 対応 |
|---|---|
| Linear API エラー（個別チケット） | スキップして続行。失敗一覧に追加 |
| Linear API レート制限 | 待機してリトライ（最大3回） |
| チケットが既に存在（重複検出漏れ） | スキップして失敗一覧に追加 |

### 実行結果レポート

~~~markdown
## Execution Result

✓ create: N件
✓ link: N件
✗ 失敗: N件
- #XX: 作成失敗 (reason)

### 変更されたチケット一覧
| チケット | 種別 | 内容 |
|---|---|---|
~~~

## Scope Boundaries

### スキルが行うこと
- 新規チケットの作成
- 既存チケットへのリンク/コメント追加

### スキルが行わないこと
- 既存チケットの構造変更（linear-cleanup の責務）
- 既存チケットの description 書き換え
- チケットの削除・クローズ
