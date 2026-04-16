---
name: continue
description: >-
  前セッションの project-state.json から未完了タスク（in_progress/blocked）を特定し、
  ユーザー承認後に作業を再開する。/continue の明示呼び出し、"continue from handover"
  のような継続指示、handover.md への言及を検出した時に使用する。worktree 切り替えと
  Pipeline Detection も含む。
user-invocable: true
---

前セッションからの引き継ぎを確認し、未完了タスクがあれば承認後に作業を再開する。

## パス解決（読み込み先の決定）

### チーム所属判定

1. 自分を起動した prompt に handover ファイルの明示的なパスが含まれるか確認する
   - 含まれる場合 → そのパスのディレクトリを使用
2. チーム所属判定（handover スキルと同じロジック）
3. **明示パスあり** → 指定されたパス
4. **チーム所属あり** → `.agents/handover/{team-name}/{agent-name}/`

### 単体セッション（チーム所属なし）

1. `{cwd}/.agents/handover/` を走査し、利用可能なセッション（status が `READY`）を収集する（グループ: **CWD**）
2. `git worktree list` で全 worktree パスを取得する
3. CWD 以外の各 worktree の `{path}/.agents/handover/` を走査し、READY セッションを収集する（グループ: **worktree**）
4. 全セッションの `workspace.root` を検証する。`git worktree list` の結果に存在しないパスを指すセッションは **orphan** とマークする
5. 候補数に応じた処理:
   - **0件** → 「再開可能なセッションがありません」と報告して終了
   - **1件以上** → `AskUserQuestion` で以下のグルーピングで一覧表示し選択させる:

     ```
     📂 現在のディレクトリ (CWD)
       [1] master/20260330-120000 — 残2件 / 完3件 — 次: execute 実装

     📂 worktree: feature/auth-refactor (.worktrees/auth-refactor)
       [2] feature/auth-refactor/20260329-140000 — 残3件 / 完1件 — 次: DB マイグレーション

     ⚠ worktree 削除済み
       [3] feature/old-feature/20260325-100000 — 残2件 / 完0件 — 次: 初期実装
     ```

     各セッションの表示項目:
     - ブランチ名、fingerprint、完了/残タスク数、次タスクの概要
     - orphan session（`workspace.root` が存在しない）には「⚠ worktree 削除済み」と警告を付ける
     - `last_touched` が 48 時間以上前のタスクがある場合は「⚠ stale（48h 以上未更新）」と警告を付ける

ステップ 2-3 は CWD の候補数に関係なく常に実行する。

## 手順

0. **Worktree 切り替え**（選択されたセッションが CWD 以外の場合のみ実行）

   選択されたセッションの所属に応じて分岐する:

   - **既存 worktree のセッション**:
     1. `wt switch <branch>` を実行して worktree に切り替える
     2. 切り替え先の `.agents/handover/` から `project-state.json` を読み込む
     3. 手順 0.5（Pipeline Detection）へ進む

   - **orphan セッション**（worktree 削除済み）:
     1. `project-state.json` の `workspace.branch` からブランチ名を取得する
     2. ブランチが git に存在するか確認する（`git branch --list <branch>`）
        - **存在しない場合** → 「ブランチも削除されています。セッションを再開できません。」と報告して終了
     3. ユーザーに確認する: 「worktree が削除されています。`wt switch --create <branch>` で再作成しますか？」
        - **拒否** → セッション選択に戻る
        - **承認** → `wt switch --create <branch>` で worktree を再作成する
     4. orphan セッションのデータ（`project-state.json`, `handover.md`）を新しい worktree の `.agents/handover/{branch}/{fingerprint}/` にコピーする
     5. 元の orphan セッションディレクトリを削除する
     6. 手順 0.5（Pipeline Detection）へ進む

   - **`wt` 未インストールの場合**:
     `wt` コマンドが利用できない場合は「`wt` が見つかりません。手動で `cd <worktree-path>` してから `/continue` を再実行してください」と報告して終了する

0.5. **Pipeline Detection**（手順1の前に実行）

   project-state.json の `pipeline` フィールドを確認する:
   - `pipeline` が存在しない、または `"feature-dev"` / `"debug-flow"` 以外の値の場合:
     → 手順1以降の従来フローを実行する
   - `pipeline` が `"feature-dev"` または `"debug-flow"` の場合:

   **Phase Summary の読み込みと表示:**

   1. `version` が 5 であることを確認する（4 の場合はレガシーフローにフォールバック）
   2. `phase_summaries` マッピングから完了済みフェーズを特定する
   3. `current_phase` を判定する（`pipeline.yml` のフェーズ配列順で、`phase_summaries` に存在しない最初のフェーズ）
   4. 現在フェーズの Phase Summary が存在する場合は Read する
   5. Phase Summary 内の `concerns` / `directives` を `target_phase` で現在フェーズにフィルタする
   6. `session` オブジェクトから `session_id` と `resume_hint` を取得する

   **表示フォーマット:**

   ```
   前回セッション:
     Session ID: {session.session_id}
     Resume hint: {session.resume_hint}

   Phase Progress:
     design ✅
     spec-review ✅
     plan ✅
     → Current: plan-review

   Concerns for current phase:
     - <concerns with target_phase matching current phase>

   Pipeline: {pipeline} のセッションを検出しました。
   {phase_id} から Resume Mode で起動します。
   ```

   → Skill tool で `/{pipeline}` を invoke する
   → continue の処理はここで終了（ワークフローに委譲）

   ### Linear からの Phase Summary 復元（フォールバック）

   ローカルの `phase-summaries/` が不在または不完全で、`linear.issue_id` が設定されている場合:

   1. `/linear-sync` の `read_phase_summary` を invoke
   2. Linear から Phase Summary を取得
   3. ローカルの `phase-summaries/` に書き戻し
   4. 通常の Pipeline Detection に戻る

   Linear API 失敗時はワークフロー続行（ベストエフォート）。

1. 上記のパス解決で選択されたセッションの `project-state.json` を読み込む
   - 存在しない場合 → 「プロジェクト状態ファイルがありません。/handover で作成してください」と報告して終了
   - JSON として不正な場合 → エラーを報告して終了
   - `version` が 4 または 5 であることを確認する。それ以外 → 「サポートされていないバージョンです（version: {version}）」と報告して終了
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

continue 実行時に、CWD および全 worktree の `.agents/handover/` 配下で `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。

## 制約

- project-state.json が存在しない、または ALL_COMPLETE の場合はコードベースの探索を行わない
- タスク実行前に必ずユーザーの承認を得る
- 設定されている言語で出力する
