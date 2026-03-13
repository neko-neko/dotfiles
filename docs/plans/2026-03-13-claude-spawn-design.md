# claude-spawn: 並列 feature-dev セッションオーケストレーター

## Goal

独立した複数の `/feature-dev` セッションを4-6個同時実行し、人間は監督役として承認ポイントのみ介入する。定型作業（worktree作成・タブ生成・セッション起動）を自動化し、並列開発のスループットを最大化する。

## Architecture

WezTerm Lua API + シェルスクリプトでセッションのライフサイクルを管理。状態管理は git-backed ファイルを source of truth とし、kanban-server はダッシュボード UI（読み取り専用）として機能する。リモートノードは zellij + SSH で管理し、母艦のスリープに依存しない設計。

## Tech Stack

- CLI: zsh スクリプト (`claude-spawn`)
- ターミナル制御: WezTerm Lua API + CLI (`wezterm cli`)
- リモートセッション: zellij (SSH経由)
- 状態管理: git-backed JSON ファイル (`~/.claude/kanban/sessions/`)
- ダッシュボード: 既存 kanban-server (Deno+Hono) の拡張
- 通知: Claude Code Notification hook + macOS terminal-notifier

---

## 全体構成図

```
┌─────────────────────────────────────────────────────┐
│                    ユーザー (監督役)                    │
│  WezTerm タブ切替 / kanban ダッシュボード で状態確認     │
└──────────┬──────────────────────────┬────────────────┘
           │                          │
     ┌─────▼──────┐           ┌──────▼───────┐
     │  WezTerm   │           │ kanban-server │
     │  Lua API   │           │  (Deno+Hono)  │
     │  タブ/WS   │           │  :3456        │
     │  制御      │           │  読み取り専用  │
     └─────┬──────┘           └──────▲───────┘
           │                          │ git pull
     ┌─────▼──────────────────────────┼────────────┐
     │          claude-spawn CLI                    │
     │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
     │  │ worktree │ │ WezTerm  │ │ Claude   │    │
     │  │ 作成     │→│ タブ生成  │→│ Code起動 │    │
     │  └──────────┘ └──────────┘ └────┬─────┘    │
     └─────────────────────────────────┼───────────┘
                                       │
     ┌────── ローカル ─────────────────┼──── リモートノード ──────┐
     │  .worktrees/feature-a/         │  SSH + zellij            │
     │  .worktrees/feature-b/         │  git-backed 状態ファイル  │
     │  .worktrees/feature-c/         │  kanban git sync         │
     └────────────────────────────────┴──────────────────────────┘
```

---

## コンポーネント一覧

| コンポーネント | 役割 | 技術 |
|---|---|---|
| `claude-spawn` | セッション起動CLI | zsh スクリプト |
| WezTerm Lua 拡張 | タブ生成・タイトル更新・ワークスペース制御 | WezTerm Lua API |
| kanban-server 拡張 | セッションダッシュボード UI | 既存 Deno+Hono に追加 |
| セッション状態ファイル | source of truth | git-backed JSON |
| Claude Code hooks | フェーズ遷移・承認待ち検知 | PostToolUse / Notification hook |

---

## claude-spawn CLI

### コマンド体系

```bash
# セッション起動
claude-spawn start --name <feature名> --desc "概要" [--remote <node名>]

# セッション一覧（git pull + ローカルファイル読み取り）
claude-spawn list

# セッションに接続（WezTermタブにフォーカス or zellij attach）
claude-spawn attach <feature名>

# セッション終了（worktree削除、状態更新）
claude-spawn clean <feature名>
claude-spawn clean --all-done         # done セッションを一括片付け
claude-spawn clean --node <node名>    # 特定ノードの全セッション片付け

# ノード管理
claude-spawn nodes                    # 登録ノード一覧 + 稼働状況
claude-spawn nodes check              # 全ノードの疎通確認

# ダッシュボード
claude-spawn dashboard                # kanban ダッシュボードをブラウザで開く
```

### `start` の内部処理

```
claude-spawn start --name auth --desc "OAuth2認証の追加"
  │
  ├─ 1. バリデーション
  │    - feature名の重複チェック（sessions/*.json 照会）
  │    - worktree パスの存在チェック
  │    - ローカル: ディスク容量チェック
  │    - リモート: SSH 疎通確認
  │    - ノードの max_sessions チェック
  │
  ├─ 2. worktree 作成
  │    - git worktree add .worktrees/auth -b feature/auth
  │    - 依存インストール（package.json 等あれば自動検出）
  │
  ├─ 3. セッション状態ファイル作成
  │    - ~/.claude/kanban/sessions/<id>.json を作成
  │    - git add + commit + push
  │
  ├─ 4. ターミナル生成
  │    ├─ ローカル: WezTerm CLI で新タブ生成
  │    │   wezterm cli spawn --cwd .worktrees/auth -- claude --resume
  │    │   タブタイトルを "[auth] feature-dev" に設定
  │    │   ワークスペース "claude-dev" に配置
  │    │
  │    └─ リモート: SSH + zellij
  │        ssh <node> "cd ~/worktrees/auth && zellij -s auth -l claude-session.kdl"
  │
  └─ 5. Claude Code に /feature-dev <desc> を自動投入
```

### `clean` の内部処理

```
claude-spawn clean auth
  │
  ├─ 1. 終了確認
  │    - status が done/failed でなければ警告・確認プロンプト
  │
  ├─ 2. ブランチ処理確認
  │    - マージ済みか確認、未マージなら警告
  │
  ├─ 3. worktree 削除
  │    - git worktree remove .worktrees/auth
  │    - リモートの場合は SSH 経由
  │
  ├─ 4. ターミナル片付け
  │    - ローカル: WezTerm タブを閉じる
  │    - リモート: zellij delete-session auth
  │
  └─ 5. セッション状態ファイル削除（またはアーカイブ）
       - git add + commit + push
```

---

## 設定ファイル

`~/.config/claude-spawn/config.toml`:

```toml
[local]
worktree_dir = ".worktrees"
max_sessions = 4

[nodes.mac-mini]
host = "mac-mini"            # ~/.ssh/config の Host名
worktree_dir = "~/worktrees"
max_sessions = 2
tailscale_ip = "100.x.x.x"

# 将来のノード追加例
# [nodes.cloud-dev]
# host = "cloud-dev"
# worktree_dir = "~/worktrees"
# max_sessions = 4
# tailscale_ip = "100.x.x.y"

[kanban]
repo = "~/.claude/kanban"
sessions_dir = "sessions"

[notifications]
enabled = true
on_waiting = true            # 承認待ちで通知
on_complete = true           # フェーズ完了で通知
```

---

## 状態管理: git-backed ファイル

### 設計方針

母艦（ローカル）が頻繁にスリープするため、kanban-server API への依存を排除。各ノードはローカルファイルに状態を書き込み、git sync で共有する。kanban-server は読み取り専用のダッシュボード UI としてのみ機能。

### データモデル

`~/.claude/kanban/sessions/<session-id>.json`:

```json
{
  "id": "auth-20260313-201500",
  "name": "auth",
  "description": "OAuth2認証の追加",
  "status": "in-progress",
  "phase": "Design",
  "host": "local",
  "worktree": ".worktrees/auth",
  "branch": "feature/auth",
  "wezterm_pane_id": "42",
  "zellij_session": null,
  "created_at": "2026-03-13T20:15:00+09:00",
  "updated_at": "2026-03-13T20:30:00+09:00",
  "waiting_since": null
}
```

- `status`: `starting` | `in-progress` | `awaiting-review` | `done` | `failed`
- `host`: `local` | ノード名

### 状態更新フロー

**書き込み（各ノード）**:
```
Claude Code PostToolUse hook
  → sessions/<id>.json を更新（ローカルファイル書き込み）
  → git add + commit + push（失敗時はリトライキューに積む）
```

**読み取り（母艦）**:
```
母艦復帰時 or claude-spawn list 実行時
  → git pull で全ノードの sessions/*.json を取得
  → kanban-server がファイルを読み込んでダッシュボード更新
  → 承認待ちがあれば通知をまとめて発火
```

---

## WezTerm 連携

### タブタイトル自動更新

```
状態遷移:
  [auth] starting...
  [auth] feature-dev: Discovery
  [auth] feature-dev: Design
  [auth] ⏳ WAITING                  ← 承認待ち（目立つ表示）
  [auth] feature-dev: Implement
  [auth] ✅ Done
```

実現方法: Claude Code Notification hook → シェルスクリプト → `wezterm cli set-tab-title`

### ワークスペース分離

```
ワークスペース "default"    ← 通常作業
ワークスペース "claude-dev" ← claude-spawn セッション専用
  ├─ タブ: [auth] feature-dev: Design
  ├─ タブ: [payment] ⏳ WAITING
  ├─ タブ: [search] feature-dev: Implement
  └─ タブ: [mac-mini:cache] feature-dev: Review
```

`Cmd+S` の既存ワークスペース切替で行き来。

### 承認待ちの視認性

| 方法 | 実装 |
|---|---|
| タブタイトル | `⏳ WAITING` プレフィックス |
| タブ色 | WezTerm `tab_bar` カラーをオレンジに変更 |
| macOS通知 | 既存の `terminal-notifier` 活用 |
| kanban | ダッシュボードで黄色表示 |

### キーバインド追加

```
Cmd+Shift+L  → claude-spawn list をオーバーレイ表示（fzf選択でattach）
Cmd+Shift+W  → 承認待ちセッション一覧（WAITING のみフィルタ）
```

---

## リモートノード実行

### zellij ベースのセッション管理

```
claude-spawn start --name cache --desc "キャッシュ層" --remote mac-mini
  │
  ├─ 1. SSH でリモート操作
  │    ssh mac-mini "git -C ~/repo worktree add ~/worktrees/cache -b feature/cache"
  │
  ├─ 2. zellij セッション作成
  │    ssh mac-mini "cd ~/worktrees/cache && zellij -s cache -l claude-session.kdl"
  │
  ├─ 3. Claude Code 起動（zellij 内）
  │    zellij セッション内で claude --resume が自動起動
  │    /feature-dev <desc> を自動投入
  │
  ├─ 4. セッション状態ファイル作成
  │    リモートの ~/.claude/kanban/sessions/<id>.json
  │    git push でローカルと同期
  │
  └─ 5. ローカルからの接続
       claude-spawn attach cache
       → WezTerm 新タブで ssh -t mac-mini "zellij attach cache"
```

### zellij レイアウト定義

`~/.config/zellij/layouts/claude-session.kdl`:

```kdl
layout {
    tab name="claude" {
        pane command="claude" {
            args "--resume"
        }
    }
}
```

### リモートノードの前提条件

各ノードに必要:
- Tailscale (VPN)
- SSH アクセス
- git + dotfiles (claude-spawn hooks 含む)
- zellij
- Claude Code
- プロジェクト依存ツール（Node/Deno 等）

---

## kanban-server 拡張

### 追加エンドポイント（読み取り専用）

```
GET /api/sessions              全セッション一覧（sessions/*.json を読み取り）
GET /api/sessions/:id          セッション詳細
GET /api/dashboard             ダッシュボード用集約データ
POST /api/sessions/sync        git pull トリガー
```

状態の書き込みは API 経由ではなく、各ノードがファイルを直接更新して git push する。

### ダッシュボード UI

既存の kanban UI（Terminal Luxe スタイル）に「Sessions」タブを追加:

```
┌─ Sessions ──────────────────────────────────────────┐
│                                                      │
│  Local (2/4)                    mac-mini (1/2)       │
│  ──────────                     ──────────           │
│  🟢 auth     Design             🟢 cache   Implement │
│  🟡 payment  ⏳ WAITING (3m)                         │
│  🟢 search   Implement                               │
│                                                      │
│  ⏳ Awaiting review: 1                               │
│  ├─ payment: Code Review 結果の確認                   │
│  └─ [Attach]                                         │
│                                                      │
│  Recent Activity                                     │
│  ──────────────                                      │
│  20:32 auth    Discovery → Design                    │
│  20:30 payment Implement → Code Review → ⏳ WAITING   │
│  20:28 search  Design → Implement                    │
│  20:15 cache   started on mac-mini                   │
└──────────────────────────────────────────────────────┘
```

---

## Claude Code hooks 連携

### フェーズ遷移の検知

PostToolUse hook でセッション状態ファイルを更新:

```
PostToolUse hook（セッション用）
  → git commit を検知 → phase 推定 → sessions/<id>.json 更新 → git push
  → AskUserQuestion を検知 → status: "awaiting-review" に更新 → git push
```

### Notification hook の拡張

```
Notification hook
  → 承認待ち検知
    → sessions/<id>.json を "awaiting-review" に更新
    → WezTerm CLI でタブタイトル変更: "[name] ⏳ WAITING"
    → macOS通知送信
```

### ワーカーの CLAUDE.md 自動配置

`claude-spawn start` 時に worktree の `.claude/CLAUDE.md` に以下を自動追記:

```markdown
# Session Context
- Session ID: auth-20260313-201500
- Session Name: auth
- フェーズ遷移時にセッション状態ファイルを更新すること
```

---

## エラーハンドリング

| シナリオ | 検出方法 | 対処 |
|---|---|---|
| Claude Code クラッシュ | zellij/WezTerm プロセス終了検知 | status → `failed`、通知送信 |
| SSH 切断（リモート） | zellij がセッション維持 | 再接続で `claude-spawn attach` |
| worktree コンフリクト | `git worktree add` 失敗 | エラー表示、既存 worktree 確認を促す |
| ノード到達不能 | `claude-spawn nodes check` | `unreachable` 表示、ローカル切替を提案 |
| kanban-server ダウン | ダッシュボード不通 | セッション自体は継続（ファイルベースで状態保全） |
| ディスク容量不足 | `start` 時の事前チェック | エラー表示、別ノードを提案 |
| git push 失敗 | hook 内の push 結果 | リトライキューに積み、次の hook 実行時に再試行 |

---

## スコープ外（YAGNI）

以下は現時点では実装しない:

- `--remote auto` による空きノード自動配置
- セッション間の依存関係管理
- feature-dev フェーズ内の並列化（1セッション内の高速化）
- kanban-server への書き込み API（git-backed で十分）
- ダッシュボードからの承認操作（ターミナルで直接操作）
