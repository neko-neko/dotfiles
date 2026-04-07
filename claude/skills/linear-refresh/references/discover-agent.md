# 発見エージェント

Step 2 (Discover) 用のサブエージェント指示。Linear チケットからリンクされていない外部ソースを Slack と GitHub で検索する。

## サブエージェント種別

2種類のサブエージェントをメインエージェントが並列でディスパッチする。

---

### Slack 検索エージェント

#### Prerequisites

1. `/slackcli` スキルを invoke して Slack CLI の使用パターンを読み込む。

#### Input

- `seeds`: Seed オブジェクトのリスト。各オブジェクトに以下を含む:
  - `ticket_id`: 関連チケット ID
  - `entities`: 検索キーワードのリスト（固有名詞・ドメイン用語・技術的識別子）
  - `budget`: 要約文字数（200 / 400 / 800）
- `exclude_urls`: Step 1 で収集済みのURL（重複排除用）
- `time_window`: 「直近30日間」

#### 手順

1. 各シードに対して slackcli で Slack 検索を実行する。
2. 各結果に対して:
   a. URLが `exclude_urls` に含まれるか確認 → 含まれればスキップ。
   b. 関連性を判断: このメッセージ/スレッドはチケットコンテキストに関連するか？
   c. 関連する場合: スレッド全体を探索し、要約 + deferred signals を抽出する。
   d. [external-source-exploration.md](external-source-exploration.md) に従って要約予算を適用する。
3. 結果を重複排除（Slack スレッドURLを親メッセージ形式に正規化）。
4. 結果が30件を超える場合、チケット優先度 + 新しさで優先順位付け。

#### 戻り値フォーマット

DiscoverySource オブジェクトの JSON 配列を返却:

```json
[
  {
    "url": "https://workspace.slack.com/archives/CHAN/p1234567890",
    "discovery_query": "PROJ-42",
    "related_tickets": ["PROJ-42", "PROJ-15"],
    "accessible": true,
    "summary": "スレッドでは月初ドロップダウンの実装を議論...",
    "latest_activity_ts": "2026-04-05T14:30:00+09:00",
    "deferred_signals": ["デプロイ後にフォローアップ予定"],
    "source_type": "slack_thread"
  }
]
```

---

### GitHub 検索エージェント

#### Prerequisites

なし（gh CLI はデフォルトで利用可能）。

#### Input

- `seeds`: Seed オブジェクトのリスト。各オブジェクトに以下を含む:
  - `ticket_id`: 関連チケット ID
  - `entities`: 検索キーワードのリスト（固有名詞・ドメイン用語・技術的識別子）
  - `budget`: 要約文字数（200 / 400 / 800）
- `repo`: 対象リポジトリ（例: `owner/repo`）
- `exclude_urls`: Step 1 で収集済みのURL

#### 手順

1. 各シードに対して `gh search issues` と `gh search prs` を `repo` スコープで実行する。
2. 各結果に対して:
   a. URLが `exclude_urls` に含まれるか確認 → 含まれればスキップ。
   b. 関連性を判断: この Issue/PR はチケットコンテキストに関連するか？
   c. 関連する場合: コメント/議論を取得し、要約 + deferred signals を抽出する。
   d. [external-source-exploration.md](external-source-exploration.md) に従って要約予算を適用する。
3. 重複排除（異なるクエリで同じ Issue がヒットした場合）。
4. 結果が30件を超える場合、チケット優先度 + 新しさで優先順位付け。

#### 戻り値フォーマット

Slack と同じ DiscoverySource オブジェクトの JSON 配列。`source_type` は `"github_issue"` または `"github_pr"`。
