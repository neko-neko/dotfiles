---
name: kanban
description: ローカル kanban ボードのタスク管理。タスクの追加・移動・表示・handover同期・サーバー起動を行う。
user-invocable: true
---

ローカル kanban ボードを操作する。データは `~/.claude/kanban/` に JSON で保存される。

## コマンド

引数に応じて以下の操作を実行する:

### `/kanban`（引数なし）
1. `~/.claude/kanban/boards.json` を読み込む
2. ボード一覧を表示する
3. 現在の `pwd` に対応するボードがあれば、そのサマリー（カラムごとのタスク数）を表示する

### `/kanban add <title>`
1. 現在の `pwd` から対応するボードを `boards.json` の `path` で検索する
2. 見つからない場合: AskUserQuestion でボード新規作成を提案する（id, name を確認）
3. `~/.claude/kanban/boards/<board-id>.json` にタスクを追加する:
   - status: `backlog`
   - priority: `medium`
   - id: `t-YYYYMMDD-NNN`（NNN はランダム3桁）
   - worktree: 現在のブランチ名（`git rev-parse --abbrev-ref HEAD`）

### `/kanban move <task-id> <status>`
1. status は `backlog`, `todo`, `in_progress`, `review`, `done` のいずれか
2. 対応するボードの JSON ファイルを更新する
3. 更新後のタスク情報を表示する

### `/kanban show`
1. 現在の `pwd` に対応するボードのタスクを読み込む
2. カラムごとにグループ化してテーブル形式で表示する:

```
| Backlog    | Todo       | In Progress | Review     | Done       |
|------------|------------|-------------|------------|------------|
| [t-001]    |            | [t-002]     |            |            |
| タスク1    |            | タスク2     |            |            |
| 🔴 high    |            | 🟡 med      |            |            |
```

### `/kanban sync`
1. 現在の `pwd` から `.claude/handover/` 配下の最新 `project-state.json` を探す
   - ブランチ名でディレクトリを特定
   - 最新の fingerprint ディレクトリを選択
2. project-state.json の `active_tasks` を読み込む
3. 既存タスクとのマッチング（タイトル = description で照合）:
   - マッチ: `updatedAt` が新しい方を採用
   - 未マッチ: 新規タスクとして追加
4. セッション情報を `sessionContext` に記録
5. 同期結果（created / updated 件数）を表示

### `/kanban serve`
1. `~/.claude/tools/kanban-server/` でサーバーを起動する:
   ```bash
   cd ~/.claude/tools/kanban-server && deno task start &
   ```
2. `http://localhost:3456` をブラウザで開く:
   ```bash
   open http://localhost:3456
   ```

## リモート管理コマンド

### `/kanban sync`（git 同期）
1. kanban データリポジトリ（`~/.claude/kanban/`）の git pull & push を実行する
2. サーバーが起動中の場合は `POST http://localhost:3456/api/sync/pull` → `POST /api/sync/push` でも可

### `/kanban remote-status`
1. `GET http://localhost:3456/api/remote/ping` でリモート Mac mini の接続状態を確認
2. 実行中タスクがあれば `GET /api/remote/status?taskId=<id>` で zellij セッション状態を表示

### `/kanban remote-launch <task-id>`
1. 指定タスクの情報とコンテキストを構築
2. `POST http://localhost:3456/api/remote/launch` でリモート Mac mini に Claude Code を起動
3. タスクの executionHost を `remote` に更新

## プロジェクト自動検出

- `pwd` と `boards.json` の各ボードの `path` をマッチングする
- `pwd` がボードの `path` の子ディレクトリでもマッチする
- ワークツリーの場合: `git worktree list --porcelain` で main worktree のパスも確認する

## データパス

- ボード一覧: `~/.claude/kanban/boards.json`
- ボードデータ: `~/.claude/kanban/boards/<board-id>.json`
- サーバーコード: `~/.claude/tools/kanban-server/`
