# slackcli スキル実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** slackcli のリファレンススキルを作成し、Slack 関連の操作依頼時に自動トリガーされるようにする

**Architecture:** 単一の SKILL.md ファイルに認証ガイド・全コマンドリファレンス・セキュリティルールを記載。既存の `claude/skills/` ディレクトリパターンに従い配置

**Tech Stack:** Markdown (SKILL.md), slackcli v0.3.1

**Spec:** `docs/superpowers/specs/2026-03-30-slackcli-skill-design.md`

---

## File Structure

| ファイル | 操作 | 責務 |
|---------|------|------|
| `claude/skills/slackcli/SKILL.md` | 新規作成 | スキル本体（認証・コマンドリファレンス・セキュリティルール） |

---

### Task 1: SKILL.md の作成

**Files:**
- Create: `claude/skills/slackcli/SKILL.md`

- [ ] **Step 1: ディレクトリ作成**

```bash
mkdir -p claude/skills/slackcli
```

- [ ] **Step 2: SKILL.md を作成**

以下の内容で `claude/skills/slackcli/SKILL.md` を作成する:

```markdown
---
name: slackcli
description: "Slack CLI: Send messages, read conversations, search, and manage Slack workspaces from the terminal. Use when the user asks anything related to Slack — sending messages, checking unreads, searching conversations, or managing workspaces."
metadata:
  version: 0.3.1
  openclaw:
    category: "productivity"
    requires:
      bins:
        - slackcli
    cliHelp: "slackcli --help"
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
```

- [ ] **Step 3: コミット**

```bash
git add claude/skills/slackcli/SKILL.md
git commit -m "feat: add slackcli reference skill"
```

---

### Task 2: スキル動作確認

- [ ] **Step 1: スキルファイルの存在確認**

```bash
cat claude/skills/slackcli/SKILL.md | head -5
```

Expected: frontmatter の `name: slackcli` が表示される

- [ ] **Step 2: slackcli のインストール確認**

```bash
which slackcli
```

Expected: slackcli のパスが表示される（未インストールの場合はスキップ可）

- [ ] **Step 3: 完了確認**

Claude Code を再起動し、以下を確認:
- `/slackcli` でスキルが発動する
- 「Slack の未読を確認して」等の自然言語でスキルが自動トリガーされる
