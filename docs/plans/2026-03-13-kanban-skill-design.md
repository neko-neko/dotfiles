# ローカル Kanban スキル設計書

## 概要

複数ワークツリーで並行作業する際のタスク管理を、ローカル kanban ボードで実現する。
Claude Code スキルと Web UI を疎結合に設計し、双方から操作可能にする。
将来的に Linear 等の外部サービスへの移行を見据え、リポジトリパターンで抽象化する。

## 目的・成功基準

- PJ ごとのタスク状況を kanban ボードで可視化できる
- PJ 横断でタスク状況を一覧できる
- Claude Code セッションと kanban タスクを紐付けられる
- Web UI から WezTerm 経由で Claude Code をコンテキスト付き起動できる
- handover.md からタスクをインポート・マージできる

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│                    Web UI (Browser)                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────┐ │
│  │ Kanban   │ │ Cross-PJ │ │ Launch Claude Code   │ │
│  │ Board    │ │ View     │ │ (WezTerm + context)  │ │
│  └────┬─────┘ └────┬─────┘ └──────────┬───────────┘ │
└───────┼────────────┼──────────────────┼─────────────┘
        │ REST API   │                  │
┌───────┴────────────┴──────────────────┴─────────────┐
│              Deno + Hono API Server                 │
│  - CRUD /api/boards/:id/tasks                       │
│  - GET  /api/boards (cross-PJ)                      │
│  - POST /api/launch (WezTerm 起動)                  │
│  - POST /api/sync   (handover import)               │
└───────────────────┬─────────────────────────────────┘
                    │ File I/O
┌───────────────────┴─────────────────────────────────┐
│           ~/.claude/kanban/                          │
│  ├── boards.json        (ボード一覧・メタ情報)       │
│  ├── boards/                                        │
│  │   ├── <project-slug>.json  (各PJのタスクデータ)   │
│  │   └── ...                                        │
│  └── config.json        (サーバー設定・ポート等)      │
└─────────────────────────────────────────────────────┘
        ↑ 直接ファイル操作
┌─────────────────────────────────────────────────────┐
│  Claude Code Skill (/kanban)                        │
│  - /kanban add <task>                               │
│  - /kanban move <task> <status>                     │
│  - /kanban sync (handover.md → kanban)              │
│  - /kanban show                                     │
└─────────────────────────────────────────────────────┘
```

### 疎結合の原則

- Claude スキルは JSON ファイルを直接読み書きする（API サーバー不要で動作）
- Web UI は API サーバー経由でデータにアクセスする
- どちらか単独でも機能する

## データモデル

### boards.json

```json
{
  "version": 1,
  "boards": [
    {
      "id": "my-project",
      "name": "My Project",
      "path": "/Users/user/repos/my-project",
      "createdAt": "2026-03-13T00:00:00Z",
      "updatedAt": "2026-03-13T00:00:00Z"
    }
  ]
}
```

### boards/\<project-slug\>.json

```json
{
  "version": 1,
  "boardId": "my-project",
  "columns": ["backlog", "todo", "in_progress", "review", "done"],
  "tasks": [
    {
      "id": "t-20260313-001",
      "title": "認証APIの実装",
      "description": "OAuth2.0 を使ったログイン機能",
      "status": "in_progress",
      "priority": "high",
      "labels": ["backend", "auth"],
      "worktree": "feature/auth",
      "sessionContext": {
        "lastSessionId": "abc123",
        "handoverFile": "/path/to/handover.md",
        "resumeHint": "--resume abc123"
      },
      "createdAt": "2026-03-13T00:00:00Z",
      "updatedAt": "2026-03-13T12:00:00Z"
    }
  ]
}
```

### 設計判断

- **ID 形式**: `t-YYYYMMDD-NNN` — 人間が読めて時系列ソートも可能
- **`sessionContext`**: Claude Code セッションとの紐付け
- **`worktree`**: ワークツリーのブランチ名で作業場所を追跡
- **`labels`**: 自由タグ。PJ横断フィルタリングに使用
- **`priority`**: high / medium / low の3段階
- **カラム定義はボードレベル**: 初期は固定5カラム

## リポジトリ抽象化

将来 Linear 等の外部サービスに移行可能にするための抽象化レイヤー。

```typescript
interface BoardRepository {
  listBoards(): Promise<Board[]>
  getBoard(id: string): Promise<Board | null>
  createBoard(input: CreateBoardInput): Promise<Board>
  deleteBoard(id: string): Promise<void>
}

interface TaskRepository {
  listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]>
  getTask(boardId: string, taskId: string): Promise<Task | null>
  createTask(boardId: string, input: CreateTaskInput): Promise<Task>
  updateTask(boardId: string, taskId: string, input: UpdateTaskInput): Promise<Task>
  deleteTask(boardId: string, taskId: string): Promise<void>
  moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]>
}
```

初期実装: `JsonFileBoardRepository` / `JsonFileTaskRepository`
将来実装: `LinearBoardRepository` / `LinearTaskRepository`

## REST API

| メソッド | パス | 用途 |
|---------|------|------|
| GET | `/api/boards` | ボード一覧 |
| POST | `/api/boards` | ボード作成 |
| DELETE | `/api/boards/:id` | ボード削除 |
| GET | `/api/boards/:id/tasks` | タスク一覧（フィルタ対応） |
| POST | `/api/boards/:id/tasks` | タスク作成 |
| PATCH | `/api/boards/:id/tasks/:taskId` | タスク更新 |
| DELETE | `/api/boards/:id/tasks/:taskId` | タスク削除 |
| POST | `/api/boards/:id/sync` | handover.md インポート |
| POST | `/api/launch` | WezTerm で Claude Code 起動 |
| GET | `/api/overview` | PJ横断ビュー |

### 競合解決

- `updatedAt` ベースの楽観的ロック
- PATCH 時に `expectedVersion`（updatedAt）を送信
- 不一致時: 409 Conflict
- Claude スキルの直接ファイル操作時: タスク単位で last-write-wins

## Web UI

### 技術選定

- **フレームワーク**: Preact + HTM（CDN、ビルドステップなし）
- **スタイリング**: Tailwind CSS（CDN）
- **ドラッグ&ドロップ**: SortableJS（CDN）
- **配信**: Hono の static file serving

### 画面構成

**ボードビュー（メイン）**:
- ヘッダー: ボード名 + PJ セレクター
- 5カラム kanban レイアウト
- タスクカード: タイトル、priority バッジ、labels、ワークツリー名
- ドラッグ&ドロップでカラム間移動
- タスククリックで詳細パネル

**タスク詳細パネル（サイドドロワー）**:
- タイトル・説明の編集
- ステータス変更
- labels 管理
- 「Claude Code で開く」ボタン
- セッション履歴表示

**PJ横断ビュー**:
- 全ボードのサマリーカード一覧
- In Progress / Review のタスク数表示
- クリックでボードに遷移

## Claude Code スキル

### コマンド体系

```
/kanban                    → ボード一覧 + 現在PJサマリー
/kanban add <title>        → タスク追加（Backlog）
/kanban move <id> <status> → ステータス変更
/kanban show               → ターミナルにボード表示
/kanban sync               → handover.md → kanban インポート
/kanban serve              → Web UI サーバー起動
```

### handover.md 同期フロー

1. 現在 PJ ディレクトリから `handover.md` を探索
2. タスクリスト（完了/未完了）をパース
3. 既存タスクとタイトル類似度でマッチング
4. マッチ時: `updatedAt` が新しい方を採用（マージ）
5. 未マッチ: 新規タスクとして追加
6. セッション情報を `sessionContext` に記録

### プロジェクト自動検出

- `pwd` と `boards.json` の `path` フィールドをマッチング
- 一致なしの場合は新規ボード作成を提案

## WezTerm 起動

Web UI の「Claude Code で開く」ボタン押下時:

```bash
# セッションIDがある場合
wezterm cli spawn --cwd <project-path> -- claude --resume <sessionId>

# セッションIDがない場合（handover.md でコンテキスト付き起動）
wezterm cli spawn --cwd <project-path> -- claude --prompt "$(cat handover.md)"
```

## 技術スタック

- **ランタイム**: Deno
- **API フレームワーク**: Hono
- **フロントエンド**: Preact + HTM + Tailwind CSS + SortableJS（全て CDN）
- **データストア**: JSON ファイル（~/.claude/kanban/）
- **起動**: `deno run server.ts` 一発起動、ビルドステップなし

## スコープ外（YAGNI）

- ユーザー認証（ローカル専用）
- リアルタイム WebSocket（初期はポーリングまたはリロード）
- タスクのコメント機能
- タスクの期限管理
- 通知機能
