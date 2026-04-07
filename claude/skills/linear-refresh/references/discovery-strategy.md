# 発見戦略

Linear チケットからリンクされていない外部ソースを発見する際の、検索クエリ生成とノイズ制御のルール。

## クエリシード生成

`.linear-refresh/collected-context.json` のチケットからシードを抽出する:

| シード種別 | ソース | 例 |
|-----------|--------|---|
| チケットID | tickets[].id | `RAKMY-98`, `RAKMY-104` |
| タイトルキーワード | tickets[].title（抽出） | `月初ドロップダウン`, `RDS スケーリング` |
| プロジェクト名 | tickets[].project（重複排除） | `rakmy` |
| ラベル名 | tickets[].labels（重複排除） | `bug`, `infrastructure` |
| 担当者名 | tickets[].assignee（重複排除） | — |

### 優先度による重み付け

| チケット優先度/ステータス | 抽出するシード |
|------------------------|--------------|
| In Progress + Urgent/High | フル: ID + キーワード + プロジェクト + ラベル |
| In Progress + Medium | ID + キーワード |
| Todo / Backlog / Low | ID のみ |
| Done / Cancelled | スキップ（シードなし） |

理由: 高優先度のアクティブチケットが発見から最も価値を得る。低優先度チケットはクエリ爆発を防ぐためIDのみ提供。

### タイトルからのキーワード抽出

- タイトルを意味のあるフレーズに分割（単語単位ではない）
- 一般的なストップワードや汎用的な用語を除外
- ドメイン固有の用語、固有名詞、技術的識別子を保持
- 例: "CS画面 発注先企業ユーザー不在エラー" → `"CS画面 発注先企業"`, `"ユーザー不在エラー"`

## 検索対象

### Slack

方法: `/slackcli` の検索コマンド

クエリ構成:
- シードごとに1検索（結合しない — Slack 検索はクエリ内でOR結合）
- チケットIDは完全一致: `RAKMY-98`
- キーワードは複合語の場合フレーズマッチ: `"RDS スケーリング"`
- プロジェクト/ラベル名は単純な語句: `rakmy`

### GitHub

方法: `gh search issues` / `gh search prs`

クエリ構成:
- プロジェクトリポジトリにスコープ: `repo:owner/repo`
- チケットID: `repo:rakmy/rakmy_server RAKMY-98`
- キーワード: `repo:rakmy/rakmy_server "RDS scaling"`

### 検索対象外

- Google Docs / Notion — 実用的な全文検索APIがない
- 画像、スクリーンショット — 検索不可
- アーカイブ済み Slack チャンネル — 陳腐化した結果が出る可能性

## ノイズ制御

### 時間枠

検索結果を**直近30日間**に限定する。それ以前の結果がアクティブな義務を示す可能性は低い。

### 重複排除

`discovery_sources[]` への追加前に:
1. Step 1 の `external_sources[].url` と照合 → 収集済みならスキップ
2. 他の `discovery_sources[].url` と照合 → 別クエリで発見済みならスキップ
3. Slack の場合: スレッドURLを正規化（親メッセージURL = 正規形）

### 関連性判断

各サブエージェントが検索結果のチケットコンテキストとの関連性を判断する:
- **関連**: コンテンツが同じ機能、バグ、システム、またはステークホルダーについて議論している
- **無関連**: キーワードが偶然一致したが、異なるトピックについて議論している
- 無関連な結果は破棄する。discovery_sources に含めない。

### 結果上限

- ソース種別ごとに最大 **30件**（30 Slack + 30 GitHub）
- 超過時: 参照元チケットの優先度（Urgent > High > Medium）、次に新しさで優先順位付け
- この上限は重複排除と関連性フィルタリング後に適用

## サブエージェントプロンプト構造

> 以下のチケットコンテキストを踏まえ、関連する議論を検索せよ。
>
> **Team:** {team_id}
> **Seeds:** {seed_list}
> **Source:** Slack | GitHub
> **Time window:** 直近30日間
> **Exclude URLs:** {already_collected_urls}
>
> 各結果について返却: url, discovery_query, related_tickets, accessible,
> summary（予算は external-source-exploration.md に従う）, latest_activity_ts,
> deferred_signals, source_type
