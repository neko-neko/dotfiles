# kanban-server

Claude Code 向けローカルカンバンボードサーバー。

## 技術スタック

- **ランタイム**: Deno v2+
- **フレームワーク**: Hono v4 (`jsr:@hono/hono@^4`)
- **テスト**: `deno test` + `@std/assert`
- **フロントエンド**: バニラ JS + Tailwind CSS (CDN) — SPA、`public/index.html`
  単体
- **データストア**: JSON ファイル (`~/.claude/kanban/`)

## コマンド

```bash
deno task dev    # 開発 (--watch 付き)
deno task start  # 本番起動
deno task test   # テスト実行
```

フォーマット: `deno fmt <対象ファイル>` リント: `deno lint <対象ファイル>`

## アーキテクチャ

```
server.ts                         # エントリポイント (Hono app 構築 + Deno.serve)
src/
  types.ts                        # 共有型定義 (Board, Task, TaskStatus, Priority 等)
  config.ts                       # KanbanConfig / RemoteHost 型 + loadConfig()
  repositories/
    board-repository.ts           # BoardRepository インターフェース
    task-repository.ts            # TaskRepository インターフェース
    json-file-board-repository.ts # JSON ファイル実装
    json-file-task-repository.ts  # JSON ファイル実装
    mod.ts                        # バレルエクスポート
  routes/
    boards.ts                     # /api/boards CRUD
    tasks.ts                      # /api/boards/:boardId/tasks CRUD
    actions.ts                    # sync, launch, handover, sessions, context
    sync.ts                       # /api/sync (git pull/push)
    remote.ts                     # /api/remote (SSH 経由リモート操作)
  services/
    sync-service.ts               # project-state.json → kanban タスク同期
    git-sync-service.ts           # Git pull/push/status (Deno.Command で git CLI 呼び出し)
    ssh-service.ts                # SSH/SCP コマンド実行 (Deno.Command で ssh/scp 呼び出し)
public/
  index.html                      # Web UI (Terminal Luxe テーマ)
```

### 設計原則

- **Repository パターン**: インターフェース (`BoardRepository`,
  `TaskRepository`) と実装 (`JsonFile*`) を分離。routes
  はインターフェースのみ依存
- **ルート関数パターン**: 各ルートファイルは `xxxRoutes(deps): Hono`
  関数をエクスポートし、server.ts で `app.route("/api", xxxRoutes(deps))`
  でマウント
- **外部コマンド実行**: git/ssh/scp/wezterm は `Deno.Command`
  で呼び出す。モック対象はサービスクラス単位
- **Thin SSH + Git Sync**: kanban サーバーはローカル専用。リモート操作は SSH
  経由、データ同期は Git のみ

## コーディング規約

- ファイル名: `kebab-case.ts`、テスト: `kebab-case_test.ts` (同一ディレクトリ)
- インポートパス: `.ts` 拡張子を明示 (Deno 標準)
- 型エクスポート: `export type` / `import type` を使用 (値と型を区別)
- エラーハンドリング: routes 層で `e.message.includes("...")`
  でエラー種別を判定し HTTP ステータスを返す
- バリデーション: routes 層の入口で必須パラメータを検証し、早期に 400 を返す

## テスト

- テストファイルはソースと同一ディレクトリに `*_test.ts` で配置
- `@std/assert` の `assertEquals`, `assertExists`, `assertRejects` 等を使用
- Repository テストは一時ディレクトリ (`Deno.makeTempDir()`)
  で実行し、後片付けする
- SSH/Git 系テストはコマンド実行のモック/スタブで外部依存を排除

## データディレクトリ

```
~/.claude/kanban/
  config.json       # サーバー設定 (ポート、リモートホスト)
  boards.json       # ボード一覧インデックス
  boards/
    <boardId>.json  # 各ボードのタスクデータ
```

このディレクトリは独立した Git リポジトリとして管理可能（リモート同期用）。

## 環境変数

| 変数              | デフォルト         | 用途           |
| ----------------- | ------------------ | -------------- |
| `KANBAN_DATA_DIR` | `~/.claude/kanban` | データ保存先   |
| `KANBAN_PORT`     | `3456`             | サーバーポート |
