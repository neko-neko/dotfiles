---
name: resume
description: >-
  Resume Gate プロトコル。handover state からのパイプライン復帰フローを定義する。
  環境復元、artifact 有効性検証、inner_loop_state によるサブステップ再開を含む。
---

# Resume Gate プロトコル

パイプライン起動時の最優先評価。handover state が存在すれば復帰、なければ新規開始。

## Phase 1: State Discovery

### Step 1: project-state.json の検索

1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
2. `pipeline` フィールドが現パイプライン名と一致するか確認
3. 一致 → **Resume Mode**（Phase 2 へ進む）
4. 不一致 or 不在 → **New Mode**（pipeline.yml の最初のフェーズから開始）

### Step 2: pipeline.yml のバージョン確認

1. `pipeline.yml` を Read し `version` フィールドを確認
2. `version: 3` → 以下のプロトコルで実行
3. それ以外 → エラー終了

## Phase 2: Environment Restoration

### Step 3: Worktree 復元

1. `project-state.json` の `artifacts.worktree_path` を確認
2. `git worktree list` で worktree の存在を検証
3. 存在する → `cd` して作業ディレクトリを設定
4. 存在しない → `git worktree add <path> <branch>` で復元
5. ロック競合（`.git/worktrees/<name>/locked` が存在）→ PAUSE（ユーザーに別セッションの終了を依頼）

### Step 4: Artifact 有効性検証

1. `current_phase` が `consumed_by` として参照する artifact を `pipeline.yml` artifacts セクションから特定
2. 各 artifact の `type` に応じた存在確認:
   - `file` → Glob で `pattern` に一致するファイルの存在チェック
   - `git_range` → `git rev-parse <start> <end>` で到達可能性を確認
   - `inline` → Phase Summary から直接取得（常に有効）
3. 無効な artifact がある → PAUSE（無効な artifact 名と原因を提示）

## Phase 3: Context Reconstruction

### Step 5: concerns/directives 抽出

1. 全完了フェーズの Phase Summary を走査
2. `concerns` と `directives` から `target_phase` = `current_phase` のものを抽出
3. 注入対象としてバッファ

### Step 6: validation_record 累積

1. 全完了フェーズの `validation_record` を収集
2. audit context に含める（後続の Audit Gate が「上流で検証済みの項目」を把握するため）

## Phase 4: Phase Dispatch

### Step 7: inner_loop_state 判定

execute フェーズの場合のみ:

1. Phase Summary の `inner_loop_state` を確認
2. `inner_loop_state` が存在し `current_substep` が null でない場合:
   - `Impl` → `remaining_tasks` のみで `subagent-driven-development` を起動。`completed_tasks` に該当するタスクはスキップ
   - `TestEnrich` → TestEnrich から再開。`impl_progress` を TestEnrich 入力コンテキストに注入
   - `Verify` → Verify から再開。`failure_history` を Failure Router に注入
3. `inner_loop_state` が存在しない or `current_substep` が null → フェーズ先頭から実行

### Step 8: ユーザー承認

1. 復元した環境情報を提示:
   - worktree パス、ブランチ名
   - 有効な artifact 一覧
   - concerns/directives の件数
2. `inner_loop_state` がある場合は再開ポイントも提示:
   - 「execute Sub-step {current_substep} から再開。タスク {completed_tasks} 完了済み、残り {remaining_tasks}」
3. ユーザー承認を得て `current_phase` から再開
