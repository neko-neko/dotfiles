---
name: daily-brief
description: >-
  朝イチ・作業再開時に、Slack 未読/メンション・Linear 担当チケット・全プロジェクトの
  handover 状態・当日の予定を1枚のブリーフに集約し、優先順位付きで提示する。
  トリアージ候補には /triage コマンドを添える。/daily-brief で起動、または
  「今日のブリーフ」「朝会して」「どこから再開する？」「今日やること」の依頼時に使用する。
user-invocable: true
argument-hint: "[--setup] [--no-slack] [--no-linear] [--no-projects] [--calendar] [--scheduled]"
---

# Daily Brief — 朝の受信箱 & 再開ポイント集約

複数クライアント・複数プロジェクトに散らばった「今日やるべきこと」を1枚のブリーフに集約する。
目的は**人間を判断とレビューに集中させること**。収集と整理は本スキルが行い、実行判断だけをユーザーに残す。

**開始時アナウンス:** 「Daily Brief を生成します（Slack / Linear / Projects{/ Calendar}）」

## Options

| Option | 効果 |
|--------|------|
| `--setup` | 設定ウィザードのみ実行（config.md を生成・更新） |
| `--no-slack` / `--no-linear` / `--no-projects` | 該当ソースをスキップ |
| `--calendar` | Google Calendar の当日予定を含める（gws-calendar スキル使用） |
| `--scheduled` | 非対話モード。質問せず生成し、PushNotification で要約を通知 |

## Security Rules（Read-Only 契約）

- 本スキルは**読み取り専用**。書き込みは自身の状態ファイル（下記 3 ファイル）のみに限定する
  - `~/.claude/daily-brief/config.md` （設定）
  - `~/.claude/daily-brief/state.json` （前回実行時刻・チャンネル別 last_seen_ts）
  - `~/.claude/daily-brief/briefs/YYYY-MM-DD.md` （生成物）
- `slackcli messages send/react/draft`、`linear issue create/update/delete`、`git push/commit` は**実行禁止**
- Slack トークン・API キーをブリーフ本文・ログに含めない
- トリアージや返信の実行は必ずユーザーの明示指示を待つ（ブリーフはコマンド候補を**提示するだけ**）

## Phase 0: Config

1. `~/.claude/daily-brief/config.md` を Read する
2. 存在しない場合、または `--setup` の場合:
   - [references/config-template.md](references/config-template.md) を Read し、テンプレートに沿って AskUserQuestion で設定を収集する（`--scheduled` 時は設定なしなら PushNotification でセットアップ未完了を通知して終了）
   - 監視チャンネルの ID は `slackcli search channels <name> --json` で解決する
   - 収集した設定を `~/.claude/daily-brief/config.md` に書き出す（`mkdir -p ~/.claude/daily-brief/briefs` も実行）
3. `~/.claude/daily-brief/state.json` を Read する。なければ `{ "last_run": null, "channels": {} }` として扱う
   - `last_run` が null の場合、収集範囲は「直近 24 時間」とする

## Phase 1: Collection（並列・すべて read-only）

**アナウンス:** 「Phase 1: 収集 — {有効なソース一覧}」

各ソースは独立している。**1つが失敗しても他を止めない**（失敗したソースはブリーフに ⚠ 付きで「取得失敗: {理由}」と記載してスキップ）。read-only な収集は並列実行する。

### 1a. Slack（`--no-slack` でスキップ）

前提: `which slackcli && slackcli auth list` で認証済みワークスペースを確認。未認証なら本セクションをスキップし、ブリーフに「slackcli 未認証」と記載。

config の各ワークスペースに対して:

```bash
# 未読一覧（DM とチャンネル）
slackcli conversations unread --workspace <ws> --json

# 監視チャンネルの新着（state.json の last_seen_ts 以降のみ）
slackcli conversations read <channel-id> --workspace <ws> --oldest <last_seen_ts> --limit 50 --json

# 自分宛メンション（config の mention_query を使用。既定は "to:me"）
slackcli search messages "<mention_query>" --workspace <ws> --sort timestamp --sort-dir desc --limit 20 --json
```

- `to:me` が 0 件かつエラーの場合は config の `user_id` を使い `"<@{user_id}>"` で再検索する
- 各メッセージについて **permalink（https://{ws}.slack.com/archives/{channel}/p{ts}）を組み立てて保持する**（トリアージ候補行で使う）
- bot の定期通知・自分自身の発言はノイズとして除外する

### 1b. Linear（`--no-linear` でスキップ）

前提: `which linear`。

config の各 workspace slug に対して、viewer 直結の GraphQL クエリで自分の担当チケットを取得する
（`issue mine` は cwd から team を推定するため、任意のディレクトリから動く下記を使う）:

```bash
linear --workspace <slug> api '{ viewer { assignedIssues(filter: {state: {type: {in: ["triage","unstarted","started"]}}}, first: 30) { nodes { identifier title url priorityLabel updatedAt state { name } } } } }'
```

- workspace slug の一覧は `linear auth list` で確認できる（検証済み: 2026-07-05, linear CLI v2.0.0）
- コマンドが失敗したら `linear issue query --help` / `linear api --help` でオプションを確認して再試行する（1回まで）

### 1c. Projects（`--no-projects` でスキップ）

config の `project_roots` の各リポジトリに対して:

```bash
# 未完了 handover セッションの検出（ブランチ名に / を含むため find を使う）
find <root>/.agents/handover -name project-state.json -maxdepth 5 2>/dev/null
```

- 見つかった project-state.json を Read し、status が READY（in_progress / blocked タスクを持つ）のものから「残タスク数・次タスクの概要・ブランチ」を抽出する
- あわせて各リポジトリの現況を取得する:

```bash
git -C <root> log -1 --format='%ar %s' && git -C <root> status --porcelain | wc -l
```

- 「最終コミットが 3 日以上前 かつ 未コミット変更あり」のリポジトリには ⚠ stale フラグを付ける

### 1d. Calendar（`--calendar` 指定時のみ）

gws-calendar スキルを invoke し、当日の予定（開始時刻・タイトル）を取得する。失敗時はスキップ。

## Phase 2: Synthesis（優先順位付け）

収集結果を以下の 4 セクションに分類する。**判断が必要なものほど上**に置く。

1. **🔴 判断待ち・ブロック中** — blocked タスク、返信を待たれている Slack スレッド、期限が近い Linear チケット
2. **📥 新規インバウンド（トリアージ候補）** — 前回実行以降の新規メンション・監視チャンネルの問い合わせ・障害報告。各行に次を添える:
   ```
   - [{ws}#{channel}] {要約 1 行} — {発言者} ({相対時刻})
     → `/triage {permalink}`
   ```
3. **🔄 再開ポイント** — プロジェクト別の in_progress タスク。handover セッションがあるものは `cd {root} && claude` + `/continue` を添える。Linear の In Progress チケットもここに束ねる
4. **📅 今日の予定** — `--calendar` 時のみ

分類の判断基準:
- 「質問・依頼・障害報告」の形をした Slack メッセージ → 📥。単なる情報共有・雑談は載せない（切り捨てた件数だけ「他 n 件の新着（ノイズ判定）」と記す）
- 同一スレッドの複数メッセージは 1 項目に束ねる
- 各セクション最大 10 項目。溢れた分は件数のみ記載

## Phase 3: Output

1. ブリーフを terminal に出力する（下記フォーマット）
2. 同内容を `~/.claude/daily-brief/briefs/YYYY-MM-DD.md` に保存する（同日 2 回目以降は上書き）
3. `state.json` を更新する: `last_run` = 現在時刻(ISO 8601)、監視チャンネルごとに最新メッセージの ts を `channels.<id>.last_seen_ts` へ

```markdown
# Daily Brief — YYYY-MM-DD (ddd)

## 🔴 判断待ち・ブロック中 (n)
...

## 📥 新規インバウンド (n)
...

## 🔄 再開ポイント (n)
...

## 📅 今日の予定
...

---
sources: slack(rakmy ✓, xxx ⚠ 取得失敗) / linear ✓ / projects ✓ | 前回実行: {last_run}
```

### `--scheduled` モード時の追加動作

- AskUserQuestion を一切使わない（設定不備・認証切れは通知して終了）
- PushNotification ツールで要約を送る: 「Daily Brief: 判断待ち{n}件 / 新規{m}件 / 再開{k}件」
- terminal 出力は省略してよい（ファイル保存は必須）

## 完了条件

- [ ] 有効な全ソースを収集した（失敗ソースは ⚠ 明記）
- [ ] ブリーフがファイルに保存された
- [ ] state.json が更新された
- [ ] 書き込みが状態ファイル 3 種以外に発生していない
