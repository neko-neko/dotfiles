# 外部ソース探索

Linear チケットからリンクされた外部ソースの収集と要約のルール。

## URL フィルタリング

探索前に各URLを分類する:

| 分類 | アクション | 例 |
|-----|----------|---|
| 探索（完全） | コンテンツ取得 + 要約 | Slack スレッド、議論のある GitHub Issues/PRs |
| メタデータのみ | タイトル + アクセス可否の確認 | Google Docs/Sheets、Notion ページ、静的ドキュメント |
| スキップ | 探索しない | 画像、スクリーンショット、登録済み attachments |

## 要約予算

予算は参照元チケットの優先度で決定する:

| チケット優先度 | 予算 | 追加要件 |
|-------------|------|---------|
| Backlog / Low | 200文字 | 基本的な要約 |
| Todo / Medium | 400文字 | `referenced_urls` を別フィールドで保持 |
| In Progress / Urgent / High | 800文字 + 生の抜粋 | 最新メッセージは可能な限り全文、言及URLを全列挙、`deferred_signals` を記録 |

## Deferred Signals

外部ソースにおける保留コミットメントを示すパターン。検出して記録する:

- 「フォローアップ予定」「後で更新します」
- 「確認中」「調査中」
- 「リリース予定」「〜にスケジュール済み」
- 「バックログに追加」「優先度を上げます」
- 「レビュー待ち」「承認待ち」

## 1ホップ探索（Step 1-5）

チケットの description と attachments にある全URLに対して:

1. 上記のフィルタリング表で分類する。
2. 「探索」URLの場合: チケットコンテキスト（タイトル、description 要約）と共に Agent を並列ディスパッチ。
3. 各エージェントは標準の ExternalSource フィールドを返却（collected-context-schema.md 参照）。
4. 専用ツールが利用不可の場合は WebFetch でフォールバック。

## 2ホップ再帰展開（Step 1-6, 1-7）

1ホップ結果の `referenced_urls` を厳密な条件下で展開する:

**全条件を満たす必要あり:**
- 参照元チケットが **In Progress** かつ **Urgent または High** 優先度
- `latest_activity_ts` が Refresh 実行から **72時間以内**

**追跡するURL種別:**

| 種別 | 例 | 理由 |
|-----|---|------|
| GitHub PR/Issue コメント | `#issuecomment-*`, `#discussion_r*` | 仕様更新、レビューFB |
| GitHub クロスリファレンス | `owner/repo#123` | 関連作業 |
| Slack スレッド（同一ワークスペース） | `slack.com/archives/.../p*` | ネストした議論 |
| 開発関連URL | `github.io`, `*.vercel.app` | 仕様書、モック、プロトタイプ |

**スキップするURL種別:**
- Step 1-5 で探索済み（重複排除）
- 静的ドキュメント（Google Docs/Sheets、Notion）— メタデータのみ
- 画像、スクリーンショット
- **3ホップ目以降**（無限展開防止）

## エージェントプロンプト構造

> 以下のコンテキストを踏まえ、URLを探索して構造化された要約を返却せよ。
>
> **Ticket:** {ticket_id} — {ticket_title}
> **URL:** {url}
> **Budget:** {budget} 文字
>
> 返却: summary, referenced_urls, latest_activity_ts, deferred_signals, source_type
