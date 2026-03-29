# slackcli スキル設計書

## 概要

slackcli（Slack ワークスペース操作 CLI）のリファレンススキルを作成する。Slack 関連の操作依頼時に自動トリガーし、Claude Code が正しいコマンドを組み立てて実行できるようにする。

## 背景・動機

- slackcli を使うたびにリポジトリ (shaharia-lab/slackcli) を参照して使い方を確認している
- gws-sheets スキルのようなリファレンス型スキルにすることで、毎回の参照コストをゼロにする

## 設計

### 配置

```
claude/skills/slackcli/SKILL.md
```

dotfiles リポジトリ内で管理する。

### スキル登録

`claude/settings.json` にスキルパスを追加する。

### Frontmatter

```yaml
---
name: slackcli
description: "Slack CLI: Send messages, read conversations, search, and manage Slack workspaces from the terminal."
metadata:
  version: 0.3.1
  openclaw:
    category: "productivity"
    requires:
      bins:
        - slackcli
    cliHelp: "slackcli --help"
---
```

- description がトリガー判定に使われる
- Slack 関連の操作依頼（メッセージ送信、未読確認、検索など）で自動発動

### SKILL.md 構成

#### 1. 前提条件

- slackcli のインストール確認
- 認証状態の確認方法（`slackcli auth list`）

#### 2. 認証セクション（ブラウザトークン系に絞る）

**parse-curl（推奨・最も簡単）:**

```bash
# クリップボードから
slackcli auth parse-curl --from-clipboard --login

# パイプ経由
pbpaste | slackcli auth parse-curl --login
```

**login-browser（手動指定）:**

```bash
slackcli auth login-browser \
  --xoxd=xoxd-YOUR-TOKEN \
  --xoxc=xoxc-YOUR-TOKEN \
  --workspace-url=https://yourteam.slack.com
```

**トークン抽出ガイド:**

```bash
slackcli auth extract-tokens
```

**その他の認証管理:**

| コマンド | 説明 |
|---------|------|
| `auth list` | 認証済みワークスペース一覧 |
| `auth set-default <workspace-id>` | デフォルトワークスペース設定 |
| `auth remove <workspace-id>` | ワークスペース削除 |
| `auth logout` | 全ワークスペースからログアウト |

#### 3. コマンドリファレンス

##### conversations — 会話管理

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `conversations list` | 会話一覧 | `--types` (public_channel,private_channel,mpim,im), `--limit` (default:100), `--exclude-archived`, `--workspace` |
| `conversations read <channel-id>` | メッセージ履歴取得 | `--thread-ts`, `--exclude-replies`, `--limit` (default:100), `--oldest`, `--latest`, `--json` |
| `conversations unread` | 未読会話一覧 | `--types` (channels,dms,groups), `--json` |

##### messages — メッセージ操作

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `messages send` | メッセージ送信 | `--recipient-id` (必須), `--message` (必須), `--thread-ts`, `--workspace` |
| `messages react` | リアクション追加 | `--channel-id` (必須), `--timestamp` (必須), `--emoji` (必須) |
| `messages draft` | 下書き作成 (ブラウザトークン専用) | `--recipient-id` (必須), `--message` (必須), `--thread-ts` |

##### search — 検索

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `search messages <query>` | メッセージ検索 | `--in`, `--from`, `--limit` (default:20), `--sort` (score/timestamp), `--sort-dir`, `--json` |
| `search channels <query>` | チャンネル検索 | `--limit` (default:20), `--json` |
| `search people <query>` | ユーザー検索 | `--limit` (default:20), `--json` |

##### saved — 保存済みアイテム

| コマンド | 説明 | 主要オプション |
|---------|------|---------------|
| `saved list` | 保存済みアイテム一覧 | `--limit` (default:20), `--state` (saved/completed), `--json` |

##### update — 更新

| コマンド | 説明 |
|---------|------|
| `update` | 最新バージョンに更新 |
| `update check` | 更新の有無を確認 |

**共通オプション:** ほぼ全コマンドに `--workspace <id\|name>` がある（デフォルト以外のワークスペースを指定可能）。

#### 4. セキュリティルール

- `messages send` / `messages react` / `messages draft` は **実行前にユーザー確認必須**（外部に影響する操作）
- 読み取り系（`conversations list/read/unread`, `search`, `saved list`）は確認なしで実行可
- トークン値をスキル内にハードコードしない
- `auth login-browser` / `auth parse-curl` 実行時、トークン値を出力に含めない

### 対象外

- 標準トークン（`auth login --token`）による認証ガイド — ブラウザトークン系のみサポート
- gws のようなサブスキル分割 — コマンド数が限定的なため単一ファイルで十分
- slackcli 自体のインストール自動化 — 手動インストール前提

## 変更対象ファイル

| ファイル | 操作 | 内容 |
|---------|------|------|
| `claude/skills/slackcli/SKILL.md` | 新規作成 | スキル本体 |
| `claude/settings.json` | 編集 | スキルパス追加 |

## 検証方法

1. Claude Code で `/slackcli` と入力してスキルが発動することを確認
2. 「Slack の未読を確認して」等の自然言語でスキルが自動トリガーされることを確認
3. 各コマンドの構文が正しく、実行できることを確認
