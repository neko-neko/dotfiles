# 収集エージェント

Step 1 (Collect) 用のサブエージェント指示。3種類の I/O サブエージェントをメインエージェントが並列でディスパッチする。

## サブエージェント種別

---

### 詳細取得エージェント

チケット詳細を10件バッチで取得する。

#### Prerequisites

1. `/linear-cli` スキルを invoke して CLI の使用パターンを読み込む。

#### Input

- `ticket_ids`: 取得対象のチケットIDリスト（バッチあたり最大10件）

#### 手順

1. 各チケットIDに対して `linear issue show {ticket_id}` を実行する。
2. 各結果から以下を抽出:
   - `attachments`: `[{ "url": "string", "title": "string" }]`
   - `description_urls`: 正規表現 `https?://[^\s)]+` で抽出したURL
   - `relations`: `{ "relatedTo": [], "blocks": [], "blockedBy": [] }`
3. エンリッチ済みチケットオブジェクトを返却。

#### 戻り値フォーマット

```json
[
  {
    "id": "RAKMY-81",
    "attachments": [{ "url": "https://...", "title": "..." }],
    "description_urls": ["https://github.com/...", "https://admin.rakmy.jp/..."],
    "relations": { "relatedTo": ["RAKMY-82"], "blocks": [], "blockedBy": [] }
  }
]
```

---

### 1ホップ探索エージェント

チケットの description と attachments からリンクされた外部URLを探索する。

#### Prerequisites

1. `/slackcli` スキルを invoke して Slack スレッド探索に備える。

#### Input

- `urls`: 探索対象のURLリスト（メインエージェントがフィルタリング済み）
- `ticket_context`: 各URLについて、参照元チケットのID、タイトル、優先度
- `classification`: URL毎の分類（explore / metadata-only）（メインエージェントが決定）

#### 手順

1. 「explore」分類の各URLに対して:
   a. Slack URL には `/slackcli`、それ以外には WebFetch を使用する。
   b. 予算内でコンテンツを要約:
      - Backlog/Low 優先度のチケット: 200文字
      - Todo/Medium: 400文字
      - In Progress/Urgent/High: 800文字 + 生の抜粋
   c. `referenced_urls`（取得コンテンツ内で言及されたURL）を抽出する。
   d. [external-source-exploration.md](external-source-exploration.md) に従って `deferred_signals` を検出する。
2. 「metadata-only」分類の各URLに対して:
   a. タイトルとアクセス可否のみ確認する。
3. ExternalSource オブジェクトを返却。

#### 戻り値フォーマット

```json
[
  {
    "url": "https://rakmy.slack.com/archives/CHAN/p123",
    "ticket_id": "RAKMY-81",
    "hop": 1,
    "accessible": true,
    "summary": "スレッドでは...",
    "referenced_urls": ["https://github.com/..."],
    "latest_activity_ts": "2026-04-05T10:00:00+09:00",
    "deferred_signals": ["テスト後に更新予定"],
    "source_type": "slack_thread"
  }
]
```

---

### 2ホップ探索エージェント

1ホップ結果の `referenced_urls` を厳密な条件下で展開する。

#### Prerequisites

1. `/slackcli` スキルを invoke して Slack スレッド探索に備える。

#### Input

- `urls`: 探索対象のURLリスト（メインエージェントが2ホップ条件でフィルタリング済み）
- `ticket_context`: 1ホップソースからの参照元チケット情報

#### 2ホップ条件（メインエージェントがディスパッチ前に適用）

URLが対象となるには以下の**全条件**を満たす必要がある:
- 参照元チケットが **In Progress** かつ **Urgent または High** 優先度
- 1ホップの `latest_activity_ts` が現在時刻から **72時間以内**

追跡するURL種別: GitHub PR/Issue コメント、クロスリファレンス、Slack スレッド、開発関連URL。
スキップするURL種別: 1ホップで探索済み、静的ドキュメント、画像、3ホップ目以降のURL。

#### 手順

1ホップ探索エージェントと同じ。ただし全結果に `hop: 2` を付与する。

#### 戻り値フォーマット

1ホップと同一。`"hop": 2` となる。
