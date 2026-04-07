# 発見戦略

Linear チケットからリンクされていない外部ソースを発見する際の、検索クエリ生成とノイズ制御のルール。

## Seed 生成

`.linear-refresh/collected-context.json` の全アクティブチケット（Done / Cancelled 以外）から seed を生成する。ステータス・優先度で対象を絞らない。

### Seed の種類

各チケットから以下の2種類の seed を生成する:

| 種別 | ソース | 例 |
|-----|--------|---|
| ID seed | tickets[].id | チケット識別子そのもの |
| Entity seed | tickets[].title + tickets[].labels から LLM が抽出 | 固有名詞・ドメイン用語・技術的識別子 |

ID seed は全チケット一律で生成する。Entity seed はオーケストレーターがチケット全体のコンテキストに基づいて判断する。

### Entity 抽出の原則

ルールではなく原則。LLM がコンテキストに基づいて判断する。

**良い seed（採用する）:**
- 固有名詞 — 特定の顧客・組織・店舗・製品を指す語
- ドメイン固有語 — チームの事業領域に固有の概念・専門用語。一般的な会話には登場しない語
- 技術的識別子 — 連携先サービス名・社内ツール名・プロトコル名
- 複合フレーズ — 2語以上を組み合わせてフレーズマッチ検索する語句

**悪い seed（除外する）:**
- 汎用動詞・操作語（修正, 追加, 削除, 対応, 設定）
- 汎用 UI 語（画面, モーダル, ボタン, 一覧, フォーム）
- 汎用技術語（API, CSV, バグ, エラー, DB）
- 助詞・接続詞・ストップワード

**判断に迷う場合の指針:**
- 「その語で検索して、このチケットに無関係な結果が大量に出るか？」→ Yes なら除外
- 「その語がなければ、関連する議論を見つけられないか？」→ Yes なら採用

### オーケストレーターの責務

Entity 抽出はオーケストレーターが行う（チケット全体のコンテキストを持っているため）。抽出結果を以下の構造でサブエージェントに渡す:

```json
[
  { "ticket_id": "<ID>", "entities": ["<固有名詞>", "<ドメイン用語>"], "budget": 400 },
  { "ticket_id": "<ID>", "entities": ["<サービス名>"], "budget": 800 }
]
```

budget は external-source-exploration.md の要約予算テーブルに従って決定する。

## 検索対象

### Slack

方法: `/slackcli` の検索コマンド

クエリ構成:
- シードごとに1検索（結合しない — Slack 検索はクエリ内でOR結合）
- チケットIDは完全一致: `PROJ-42`
- キーワードは複合語の場合フレーズマッチ: `"RDS スケーリング"`
- プロジェクト/ラベル名は単純な語句: `rakmy`

### GitHub

方法: `gh search issues` / `gh search prs`

クエリ構成:
- プロジェクトリポジトリにスコープ: `repo:owner/repo`
- チケットID: `repo:owner/repo PROJ-42`
- キーワード: `repo:owner/repo "検索フレーズ"`

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

> 以下の seed リストに基づき、関連する議論を検索せよ。
>
> **Team:** {team_id}
> **Seeds:**
> ```json
> [
>   { "ticket_id": "<ID>", "entities": ["<固有名詞>", "<ドメイン用語>"], "budget": 400 },
>   ...
> ]
> ```
> **Source:** Slack | GitHub
> **Time window:** 直近30日間
> **Exclude URLs:** {already_collected_urls}
>
> 各 seed について:
> 1. ticket_id で ID 検索を実行
> 2. entities の各語でキーワード検索を実行
> 3. 結果を budget 文字数で要約
>
> 各結果について返却: url, discovery_query, related_tickets, accessible,
> summary, latest_activity_ts, deferred_signals, source_type
