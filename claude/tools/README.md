# Claude Tools

Claude Code のワークフローを拡張する自作ツール群。

## kanban-server

ローカルで動作するカンバンボードサーバー。Claude Code のセッション管理・タスク追跡・リモート実行を Web UI で提供する。

### 技術スタック

| レイヤー | 技術 |
|---|---|
| ランタイム | [Deno](https://deno.com/) |
| Web フレームワーク | [Hono](https://hono.dev/) v4 (JSR: `@hono/hono`) |
| フロントエンド | Tailwind CSS (CDN), バニラ JS |
| データストア | JSON ファイル (`~/.claude/kanban/`) |
| 同期 | Git (push/pull) |
| リモート実行 | SSH + zellij |

### ディレクトリ構成

```
~/.claude/tools/kanban-server/
├── server.ts                  # エントリポイント (Hono app + Deno.serve)
├── deno.json                  # タスク定義・import map
├── public/
│   └── index.html             # SPA (Terminal Luxe テーマ)
└── src/
    ├── types.ts               # Board, Task, TaskStatus 等の型定義
    ├── config.ts              # KanbanConfig, RemoteHost, loadConfig()
    ├── repositories/
    │   ├── board-repository.ts      # BoardRepository インターフェース
    │   ├── task-repository.ts       # TaskRepository インターフェース
    │   ├── json-file-board-repository.ts   # JSON ファイル実装
    │   └── json-file-task-repository.ts    # JSON ファイル実装
    ├── routes/
    │   ├── boards.ts          # GET/POST/DELETE /api/boards
    │   ├── tasks.ts           # CRUD /api/boards/:boardId/tasks
    │   ├── actions.ts         # sync, launch, handover, sessions, context
    │   ├── sync.ts            # GET/POST /api/sync (git pull/push)
    │   └── remote.ts          # GET/POST /api/remote (SSH 経由リモート操作)
    └── services/
        ├── sync-service.ts    # project-state.json → kanban タスク同期
        ├── git-sync-service.ts # Git pull/push/status
        └── ssh-service.ts     # SSH/SCP コマンド実行
```

### セットアップ

#### 1. Deno のインストール

```bash
# mise (推奨)
mise install deno@latest
mise use -g deno@latest

# または公式インストーラ
curl -fsSL https://deno.land/install.sh | sh
```

Deno v2 以上が必要。`deno --version` で確認する。

#### 2. サーバーコードの配置

kanban-server は `~/.claude/tools/kanban-server/` に独立した Git リポジトリとして管理されている。dotfiles リポジトリからシンボリックリンクで参照する構成。

```bash
# dotfiles を clone 済みの場合
ls ~/.dotfiles/claude/tools/kanban-server/  # ソースを確認

# ~/.claude/tools にリンク (まだない場合)
mkdir -p ~/.claude/tools
ln -s ~/.dotfiles/claude/tools/kanban-server ~/.claude/tools/kanban-server
```

#### 3. 依存パッケージのキャッシュ

```bash
cd ~/.claude/tools/kanban-server
deno cache server.ts
```

`deno.json` の import map から JSR パッケージ (`@hono/hono`, `@std/assert`, `@std/path`, `@std/fs`) が自動的にダウンロードされる。

#### 4. データディレクトリの初期化

サーバー起動時に `~/.claude/kanban/` と `boards.json` は自動作成されるが、Git 同期を使う場合は事前にリポジトリとして初期化する。

```bash
# データディレクトリを Git リポジトリとして初期化
mkdir -p ~/.claude/kanban
cd ~/.claude/kanban
git init

# .gitignore を作成
cat > .gitignore << 'EOF'
# Temp files
*.tmp
*.bak

# OS files
.DS_Store
EOF

git add -A && git commit -m "init: kanban data repository"
```

#### 5. 設定ファイルの作成 (任意)

リモート実行やポート変更が不要であればスキップ可能。

```bash
cat > ~/.claude/kanban/config.json << 'EOF'
{
  "port": 3456,
  "dataDir": "~/.claude/kanban",
  "remotes": {},
  "defaultRemote": null
}
EOF
```

リモートホストを追加する場合は後述の[設定ファイル](#設定ファイル)セクションを参照。

#### 6. サーバーの起動

```bash
cd ~/.claude/tools/kanban-server

# 開発モード (--watch でソース変更時に自動リロード)
deno task dev

# 本番モード
deno task start

# テスト実行
deno task test
```

サーバーは `http://localhost:3456` で起動する。ブラウザでアクセスすると Web UI が表示される。

#### 7. Git リモート同期のセットアップ (任意)

ローカルとリモートマシン間で kanban データを同期する場合:

```bash
cd ~/.claude/kanban

# ベアリポジトリをリモートに作成 (例: mac-mini)
ssh mac-mini 'git init --bare ~/.claude/kanban-remote.git'

# ローカルにリモートを追加
git remote add origin mac-mini:~/.claude/kanban-remote.git
git push -u origin main
```

リモート設定後、サーバー起動時に自動 pull が実行される。Web UI の Sync ボタンで手動 push/pull も可能。

#### 8. リモート実行のセットアップ (任意)

SSH 経由でリモートマシン上の Claude Code を操作する場合:

**前提条件:**
- リモートマシンへの SSH 公開鍵認証が設定済み
- リモートマシンに Deno, Claude Code, zellij がインストール済み
- (推奨) Tailscale VPN でリモートマシンに接続可能

```bash
# SSH config にホストを追加 (~/.ssh/config)
Host mac-mini
    HostName 100.x.x.x    # Tailscale IP またはホスト名
    User your-user
    IdentityFile ~/.ssh/id_ed25519

# 接続テスト
ssh mac-mini 'echo ok'

# config.json にリモートホストを追加
cat > ~/.claude/kanban/config.json << 'EOF'
{
  "port": 3456,
  "dataDir": "~/.claude/kanban",
  "remotes": {
    "mac-mini": {
      "host": "mac-mini",
      "repos": {
        "kanban": "~/.claude/kanban"
      },
      "zellijLayout": "compact"
    }
  },
  "defaultRemote": "mac-mini"
}
EOF
```

Web UI からリモートホストの ping、Claude Code セッションの起動・ステータス確認が行える。

#### 環境変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `KANBAN_DATA_DIR` | `~/.claude/kanban` | ボードデータの保存先 |
| `KANBAN_PORT` | `3456` | サーバーのリッスンポート |

#### Deno パーミッション

`deno.json` の tasks に設定済み。手動実行する場合は以下が必要:

| フラグ | 用途 |
|---|---|
| `--allow-net` | HTTP サーバー |
| `--allow-read` | JSON データ・設定ファイル読み取り |
| `--allow-write` | JSON データ書き込み |
| `--allow-run` | git, ssh, scp, wezterm コマンド実行 |
| `--allow-env` | 環境変数 (HOME, KANBAN_DATA_DIR 等) |

### 設定ファイル

`~/.claude/kanban/config.json` でリモートホストやポートを設定する。

```json
{
  "port": 3456,
  "dataDir": "~/.claude/kanban",
  "remotes": {
    "mac-mini": {
      "host": "mac-mini",
      "repos": {
        "kanban": "~/.claude/kanban"
      },
      "zellijLayout": "compact"
    }
  },
  "defaultRemote": "mac-mini"
}
```

| フィールド | 型 | 説明 |
|---|---|---|
| `port` | `number` | サーバーポート (デフォルト: 3456) |
| `dataDir` | `string` | kanban データディレクトリ |
| `remotes` | `Record<string, RemoteHost>` | リモートホスト定義 |
| `remotes.*.host` | `string` | SSH ホスト名 (`~/.ssh/config` のホスト名) |
| `remotes.*.user` | `string?` | SSH ユーザー (省略時はデフォルトユーザー) |
| `remotes.*.repos` | `Record<string, string>` | リモート上のリポジトリパス |
| `remotes.*.zellijLayout` | `string?` | zellij レイアウト名 |
| `defaultRemote` | `string?` | デフォルトのリモートホスト名 |

### API リファレンス

#### ヘルスチェック

```
GET /api/health → { "status": "ok" }
```

#### ボード管理

```
GET    /api/boards                    → Board[]
POST   /api/boards                    → Board (201)
         body: { id, name, path }
DELETE /api/boards/:id                → 204
```

#### タスク管理

```
GET    /api/boards/:boardId/tasks     → Task[]
         ?status=todo&priority=high&label=bug
POST   /api/boards/:boardId/tasks     → Task (201)
         body: { title, description?, status?, priority?, labels?, worktree?, sessionContext?, executionHost?, remoteSessionName? }
PATCH  /api/boards/:boardId/tasks/:id → Task
         body: { title?, status?, priority?, ... , expectedVersion? }
DELETE /api/boards/:boardId/tasks/:id → 204
```

**TaskStatus**: `backlog` | `todo` | `in_progress` | `review` | `done`
**Priority**: `high` | `medium` | `low`

#### Git 同期

```
GET  /api/sync/status → { isRepo, dirty, branch, hasRemote, lastCommit }
POST /api/sync/pull   → { pulled, error? }
POST /api/sync/push   → { committed, pushed, error? }
```

起動時に自動 pull を試みる。リモートが未設定の場合はスキップされる。

#### リモート実行

```
GET  /api/remote/hosts              → { hosts, defaultRemote }
GET  /api/remote/ping?host=mac-mini → { host, online, latencyMs }
POST /api/remote/launch             → { status, host, sessionName, taskId }
       body: { taskId, taskTitle?, projectPath, context?, host? }
GET  /api/remote/status?taskId=T1&host=mac-mini → { taskId, host, sessionName, status }
```

`POST /remote/launch` は以下を実行する:
1. リモートの作業リポジトリで `git pull`
2. リモートの kanban リポジトリで `git pull`
3. コンテキストファイルを SCP で転送 (指定時)
4. zellij セッション内で Claude Code を起動

#### アクション

```
POST /api/boards/:boardId/sync      → { created, updated, errors }
       body: { projectState, handoverFile? }
POST /api/launch                    → { status, command }
       body: { projectPath, sessionId?, handoverFile?, context? }
GET  /api/overview                  → BoardOverview[]
```

#### Handover セッション

```
GET /api/handover/sessions?root=/path&branch=master → Session[]
GET /api/handover/content?dir=/path/.claude/handover/master/xxx → { handover, projectState, fingerprint }
```

#### Claude Code セッション履歴

```
GET  /api/sessions/list?project=/path                    → Session[] (最新20件)
GET  /api/sessions/:id/messages?project=/path&limit=50   → { sessionId, slug, messages, totalCount }
POST /api/context/build                                  → { context, sessionCount, messageCount, tokenEstimate }
       body: { project, sessionIds, includeHandover?, handoverDir? }
```

### アーキテクチャ

```
┌─────────────┐     HTTP      ┌──────────────────┐
│  Web UI     │──────────────→│  Hono Server     │
│  (SPA)      │←──────────────│  :3456           │
└─────────────┘               ├──────────────────┤
                              │ Routes           │
                              │  boards / tasks  │──→ JsonFile*Repository ──→ ~/.claude/kanban/*.json
                              │  actions         │──→ SyncService / WezTerm
                              │  sync            │──→ GitSyncService ──→ git CLI
                              │  remote          │──→ SshService ──→ ssh/scp CLI
                              └──────────────────┘
                                                          │
                                                     SSH + zellij
                                                          ↓
                                                  ┌──────────────┐
                                                  │ Remote Host  │
                                                  │ (mac-mini)   │
                                                  └──────────────┘
```

**設計方針**: Thin SSH + Git Sync アーキテクチャ。kanban サーバーはローカルのみで動作し、リモート操作は SSH 経由で実行する。データ同期は Git が唯一のメカニズム。
