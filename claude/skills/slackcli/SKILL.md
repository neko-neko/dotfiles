---
name: slackcli
description: >-
  Slack CLI: Send messages, read conversations, search, and manage Slack
  workspaces from the terminal. Use when the user asks anything related to
  Slack — sending messages, checking unreads, searching conversations, or
  managing workspaces. Also trigger when a Slack URL is provided
  (e.g., https://*.slack.com/archives/*, app.slack.com/*) or when the
  conversation context mentions Slack threads, channels, or messages.
---

# slackcli

Slack ワークスペースを操作する CLI ツール。メッセージ送信・会話管理・検索・保存済みアイテムの操作が可能。

## Security Rules

- `messages send` / `messages react` / `messages draft` は **実行前にユーザー確認必須**（外部に影響する操作）
- 読み取り系（`conversations list/read/unread`, `search`, `saved list`）は確認なしで実行可
- トークン値を出力に含めない

## Prerequisites

```bash
# インストール確認
which slackcli

# 認証状態の確認
slackcli auth list
```

未認証の場合は「認証セットアップ」セクションを案内する。

## 認証セットアップ（ブラウザトークン）

### parse-curl（推奨・最も簡単）

ブラウザの DevTools で Slack API リクエストを右クリック → Copy as cURL → CLI にペースト。

```bash
# クリップボードから自動抽出してログイン
slackcli auth parse-curl --from-clipboard --login

# パイプ経由
pbpaste | slackcli auth parse-curl --login

# インタラクティブモード
slackcli auth parse-curl --login
```

### login-browser（手動指定）

ブラウザの DevTools から `xoxd` / `xoxc` トークンを手動で抽出して指定する。

```bash
slackcli auth login-browser \
  --xoxd=xoxd-YOUR-TOKEN \
  --xoxc=xoxc-YOUR-TOKEN \
  --workspace-url=https://yourteam.slack.com
```

トークン抽出手順のガイドを表示:

```bash
slackcli auth extract-tokens
```

### 認証管理

| コマンド | 説明 |
|---------|------|
| `slackcli auth list` | 認証済みワークスペース一覧 |
| `slackcli auth set-default <workspace-id>` | デフォルトワークスペース設定 |
| `slackcli auth remove <workspace-id>` | ワークスペース削除 |
| `slackcli auth logout` | 全ワークスペースからログアウト |

## Command Reference

共通オプション: ほぼ全コマンドに `--workspace <id|name>` がある（デフォルト以外のワークスペースを指定可能）。

### conversations — 会話管理

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `slackcli conversations list` | 会話一覧 | `--types` (public_channel,private_channel,mpim,im), `--limit` (default:100), `--exclude-archived`, `--cursor`, `--workspace` |
| `slackcli conversations read <channel-id>` | メッセージ履歴取得 | `--thread-ts`, `--exclude-replies`, `--limit` (default:100), `--oldest`, `--latest`, `--workspace`, `--json` |
| `slackcli conversations unread` | 未読会話一覧 | `--types` (channels,dms,groups), `--workspace`, `--json` |

### messages — メッセージ操作

> **注意:** send / react / draft は実行前にユーザー確認を取ること。

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `slackcli messages send` | メッセージ送信 | `--recipient-id` (必須), `--message` (必須), `--thread-ts`, `--workspace` |
| `slackcli messages react` | リアクション追加 | `--channel-id` (必須), `--timestamp` (必須), `--emoji` (必須), `--workspace` |
| `slackcli messages draft` | 下書き作成 (ブラウザトークン専用) | `--recipient-id` (必須), `--message` (必須), `--thread-ts`, `--workspace` |

### search — 検索

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `slackcli search messages <query>` | メッセージ検索 | `--in`, `--from`, `--limit` (default:20), `--page`, `--sort` (score/timestamp), `--sort-dir` (asc/desc), `--workspace`, `--json` |
| `slackcli search channels <query>` | チャンネル検索 | `--limit` (default:20), `--workspace`, `--json` |
| `slackcli search people <query>` | ユーザー検索 | `--limit` (default:20), `--workspace`, `--json` |

### saved — 保存済みアイテム

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `slackcli saved list` | 保存済みアイテム一覧 | `--limit` (default:20), `--state` (saved/completed), `--workspace`, `--json` |

### update — 更新

| コマンド | 説明 |
|---------|------|
| `slackcli update` | 最新バージョンに更新 |
| `slackcli update check` | 更新の有無を確認 |

## Discovering Commands

```bash
# ヘルプ表示
slackcli --help
slackcli <command> --help
```
