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

### Step 0-3: 外部リンクの 1 ホップ探索

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

#### 要約予算の動的決定

対象チケットの優先度・ステータスに応じて要約予算を決定する:

| 条件 | summary 予算 | 追加要件 |
|---|---|---|
| Backlog / Low priority | 200字 | 従来通り |
| Todo / Medium priority | 400字 | `referenced_urls` を別フィールドで保持 |
| In Progress / Urgent / High priority | 800字 + raw excerpts | 最新メッセージは可能な限り全文、言及 URL を全列挙、`deferred_signals` を記録 |

#### 必須戻り値

| フィールド | 内容 |
|---|---|
| `url` | 探索対象 URL |
| `ticket_id` | 参照元チケット |
| `hop` | 1（Step 0-3 で取得） |
| `accessible` | 取得成否 |
| `summary` | 予算に応じた要約 |
| `referenced_urls` | 本文中で言及された他の URL（Step 0-3b の入力） |
| `latest_activity_ts` | 最終メッセージ/コメントのタイムスタンプ (ISO 8601) |
| `deferred_signals` | 「追記しました」「確認中」「リリース予定」等の deferred commitment パターン検出結果 |
| `source_type` | slack_thread / github_issue / github_pr / github_comment / document 等 |

### Step 0-3b: 二次参照の再帰展開

Step 0-3 の探索結果から `referenced_urls` を抽出し、追加探索キューに投入する。

#### 対象チケットの絞り込み

以下の AND 条件を満たす探索結果のみ再帰展開する（ノイズ削減）:

- In Progress + Urgent/High priority のチケットに紐づく
- `latest_activity_ts` が Refresh 実行から 72 時間以内

#### 追跡する URL 種別

| 種別 | 例 | 追跡理由 |
|---|---|---|
| GitHub PR/Issue コメント | `#issuecomment-*`, `#discussion_r*` | 仕様更新・レビューFBが蓄積される |
| GitHub PR/Issue 間参照 | `owner/repo#123` | 関連作業のクロスリファレンス |
| 同一ワークスペース内 Slack スレッド | `slack.com/archives/.../p*` | ネストした議論の追跡 |
| モック / 仕様書 URL | `github.io`, `*.vercel.app` 等の開発関連ホスト | 仕様書・モック・プロトタイプ |

#### 追跡しない URL 種別

- 既に Step 0-3 で探索済みの URL（重複排除）
- 3 ホップ目以降（無限展開防止）
- 静的ドキュメント（Google Docs/Sheets、Notion 等）— メタデータのみ
- 画像ファイル、スクリーンショット

#### 実行

Agent tool で並列探索。戻り値スキーマは Step 0-3 と同じだが、`hop: 2` でマークする。
結果は Step 0-4 の CollectedContext に `external_sources` として含める。

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
    - hop: number                # 1 = Step 0-3, 2 = Step 0-3b
    - accessible: boolean
    - summary: string            # 優先度に応じた予算で要約（200/400/800字）
    - referenced_urls: [string]  # 本文中で言及された他 URL（Step 0-3b の入力）
    - latest_activity_ts: string # 最終アクティビティ (ISO 8601)
    - deferred_signals: [string] # deferred commitment パターン検出結果
    - source_type: string        # slack_thread, github_issue, github_pr, github_comment, document, etc.
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

### Step 3-0: Ground Truth Audit（Plan 生成前の監査）

Plan A + Plan B を生成する前に、各 In Progress チケットについて以下の監査質問に回答する。

#### Q1. 実装者向け ground truth 監査

「このチケットを明日実装者が引き継ぐとして、知るべき最新の仕様・決定は？」

- Plan A の「コンテキスト追加」セクションに反映されているか
- 反映されていない場合、どのソース（Step 0-3 / 0-3b の結果）を再確認すべきか

#### Q2. 最近の活動監査

「このチケットの最新イベントは？」

- `latest_activity_ts` が Refresh 実行から 72 時間以内か
- 72 時間以内の活動があり、かつ `deferred_signals` が非空の場合、該当する deferred commitment が Plan に反映されているか

#### Q3. 未追跡参照監査

「このチケットに紐づく未追跡の URL は？」

- Step 0-3 の `referenced_urls` で、Step 0-3b の絞り込み条件に該当しなかったため未探索のものが残っていないか
- 残っている場合、Plan に「未追跡参照」として記録するか、Phase 0 に戻って追加探索するか判断

#### 監査結果の取り扱い

監査質問に NO があり、かつ追加探索が必要な場合:

- 該当 URL のみを対象に単発探索を実行
- 結果を CollectedContext に追加し、Plan A/B を再生成

### Step 3-1: 統合 Plan の提示

Plan A と Plan B を1つのドキュメントにまとめて提示する。変更がないセクションは省略する。

#### 統合 Plan フォーマット

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

#### 承認フロー

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
