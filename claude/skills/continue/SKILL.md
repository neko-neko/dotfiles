---
name: continue
description: handover.md から未完了タスクを確認し、承認後に作業を再開する
user-invocable: true
---

前セッションからの引き継ぎを確認し、未完了タスクがあれば承認後に作業を再開する。

## パス解決（読み込み先の決定）

### チーム所属判定

1. 自分を起動した prompt に handover ファイルの明示的なパスが含まれるか確認する
   - 含まれる場合 → そのパスのディレクトリを使用
2. チーム所属判定（handover スキルと同じロジック）
3. **明示パスあり** → 指定されたパス
4. **チーム所属あり** → `.claude/handover/{team-name}/{agent-name}/`

### 単体セッション（チーム所属なし）

1. `{cwd}/.claude/handover/` を走査し、利用可能なセッション（status が `READY`）を収集する
2. v2 互換: `{cwd}/.claude/project-state.json` が存在する場合、候補に含める（選択後にマイグレーション）
3. 候補がない場合、`git worktree list` で他の worktree の `.claude/handover/` も検索する。見つかった場合:
   > CWD にはセッションがありませんが、worktree `{path}` に以下のセッションがあります:
4. 候補数に応じた処理:
   - **0件** → 「再開可能なセッションがありません」と報告して終了
   - **1件以上** → `AskUserQuestion` で一覧表示し選択させる。表示内容:
     - ブランチ名、fingerprint、完了/残タスク数、次タスクの概要
     - orphan session（`workspace.root` が存在しない）には「⚠ worktree 削除済み」と警告を付ける

## 手順

1. 上記のパス解決で選択されたセッションの `project-state.json` を読み込む
   - 存在しない場合 → 「プロジェクト状態ファイルがありません。/handover で作成してください」と報告して終了
   - JSON として不正な場合 → エラーを報告して終了
   - 必須フィールド（version, status, active_tasks）が欠けている場合 → エラーを報告して終了

2. `git log --oneline -5` を実行し、直近のコミット履歴を確認する
   - active_tasks 内の done タスクの commit_sha が実際のコミット履歴に存在するか照合する

3. status フィールドを確認する
   - `ALL_COMPLETE` の場合 → 「全タスク完了済みです。新しい作業の指示を待ちます。」と報告して**即座に終了**する。コードベースの探索は行わない
   - `READY` の場合 → 次のステップへ

4. 未完了タスク（status が `in_progress` または `blocked`）を以下の形式で一覧表示する:
   - タスクID、説明、ステータス
   - 関連ファイルパス（file_paths）
   - 次のアクション（next_action）
   - ブロッカー（blockers があれば表示）
   - `last_touched` が 48 時間以上前のタスクには「⚠ stale（48h 以上未更新）」と警告を付ける

5. 作業開始の確認:
   - 後継エージェントとして起動された場合（prompt に「後継エージェント」を含む）→ 承認をスキップし即座に作業を開始する
   - それ以外 → ユーザーに「これらのタスクを優先順に進めますか？」と確認する（承認されるまで作業を開始しない）

6. 承認後、未完了タスクを一覧の順序で実行する
   - 各タスク完了時に選択されたセッションの `project-state.json` を更新する:
     - status を `done` に変更
     - commit_sha を記録（コミットした場合）
     - last_touched を現在時刻に更新
   - 全タスクの status が `done` になったら、トップレベルの status を `ALL_COMPLETE` に設定

7. 最後に選択されたセッションの `handover.md` を `project-state.json` から再生成する
   - handover.md のフォーマットは以下の通り:

```
# Session Handover
> Generated: {ISO8601}
> Session: {session_id}
> Status: {READY | ALL_COMPLETE}

## Completed
- [ID] タスク説明 (commit_sha)

## Remaining
- [ID] **status** タスク説明
  - files: ファイルパス
  - next: 次のアクション

## Blockers
- ブロッカー一覧

## Context
- recent_decisions から決定事項とその理由

## Architecture Changes (Recent)
- sha: 要約

## Known Issues
- [severity] 問題の説明
```

## Cleanup

continue 実行時に、`{cwd}/.claude/handover/` 配下の `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。

## 制約

- project-state.json が存在しない、または ALL_COMPLETE の場合はコードベースの探索を行わない
- タスク実行前に必ずユーザーの承認を得る
- 設定されている言語で出力する
