---
name: feature-dev
description: >-
  品質ゲート付き開発オーケストレーター。9フェーズで設計→レビュー→計画→レビュー→
  実装→コードレビュー→テストレビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Phase 8 (Test Review) を有効化。
  /tdd-orchestrate の後継。
user-invocable: true
---

# Feature Dev Orchestrator

9つの superpowers スキルとカスタムレビュースキルを1セッション（複数セッション跨ぎ可）で順次 invoke し、feature spec から merge-ready なコードまでを品質ゲート付きで実行する。

**開始時アナウンス:** 「Feature Dev を開始します。Phase 1: Design」

## Input

`/feature-dev` の引数、または会話で提供された feature spec。最低要件: **何を作るか** + **なぜ作るか**。

feature spec が不足している場合はユーザーに確認する。推測で進めない。

## Arguments

| 引数 | 説明 |
|------|------|
| (なし) | 全フェーズ実行（Phase 8 はスキップ） |
| `--codex` | 全レビューフェーズで Codex 並列レビューを有効化 |
| `--e2e` | Phase 8（Test Review）を有効化 |
| `--codex --e2e` | 組み合わせ可能 |
| `--ui` | Phase 2・Phase 4 に UI レビューエージェントを追加 |
| `--codex --e2e --ui` | 全組み合わせ可能 |

## The Pipeline

```
Feature Spec
    |
    v
Phase 1: Design ──────── superpowers:brainstorming [INTERACTIVE]
    | 設計書コミット済み -> 自動遷移
    v
Phase 2: Spec Review ─── /spec-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    | 不合格 -> ユーザーヒアリング -> 修正 -> 再レビュー
    v
Phase 3: Plan ────────── superpowers:writing-plans [AUTONOMOUS]
    | 計画書コミット済み -> 自動遷移
    v
Phase 4: Plan Review ─── /implementation-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    | 不合格 -> ユーザーヒアリング -> 修正 -> 再レビュー
    v
Phase 5: Workspace ───── superpowers:using-git-worktrees [AUTONOMOUS+GATE]
    | テスト通過 -> 自動遷移
    v
Phase 6: Execute ─────── superpowers:subagent-driven-development [AUTONOMOUS+GATE]
    | 全タスク完了 -> 自動遷移
    v
Phase 7: Code Review ─── /code-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 8: Test Review ─── /test-review [--e2e 指定時のみ] [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 9: Integrate ───── superpowers:finishing-a-development-branch [INTERACTIVE]
    |
    v
  Complete
```

## Trace 記録（フェーズ遷移）

各 Phase の開始時と終了時に trace を記録する。handover セッションディレクトリが存在する場合のみ実行する。

### 初期化（Phase 1 開始前）

1. Bash で handover ディレクトリを解決し、TRACE_FILE を設定する:
   ```bash
   source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
   source ~/.dotfiles/claude/skills/handover/scripts/handover-lib.sh
   TRACE_FILE=$(_trace_resolve_path "$(resolve_handover_dir 2>/dev/null || echo '')")
   echo "$TRACE_FILE"
   ```

2. ディレクトリが空文字の場合、このセッション中の trace 記録をすべてスキップする。

### 各 Phase 遷移時

Phase をアナウンスする際に、以下を Bash で実行する:

**Phase 開始時:**
```bash
source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
TRACE_SESSION_ID="${SESSION_ID:-unknown}"
phase_start_time=$(date +%s%3N)
trace_phase_start "$TRACE_FILE" "feature-dev" <phase_number> "<phase_name>"
```

**Phase 終了時（次の Phase に遷移する直前、または pipeline 終了時）:**
```bash
source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
TRACE_SESSION_ID="${SESSION_ID:-unknown}"
duration_ms=$(( $(date +%s%3N) - phase_start_time ))
trace_phase_end "$TRACE_FILE" "feature-dev" <phase_number> "<phase_name>" $duration_ms
```

### リトライ時

レビュー不合格→修正→再レビューが発生した場合:
```bash
trace_retry "$TRACE_FILE" "feature-dev" <phase_number> <attempt> "<reason>"
```

## Phase Details

### Phase 1: Design

- **INVOKE:** `superpowers:brainstorming`
- **Autonomy:** INTERACTIVE
- **動作:** feature spec をもとに brainstorming で設計書を作成する。ユーザーとの対話で設計を詰める
- **コードベース調査:** clarifying questions 完了後、approaches 提示前に以下を実施する:
  1. **影響範囲の調査** — 変更対象のモデル・コントローラ・ジョブ等を起点に、Grep/Read で関連コード（呼び出し元、依存先、同じテーブルを参照する箇所）を探索する
  2. **暗黙ルールの抽出** — 調査で見つけた既存コードのバリデーション・条件分岐・ビジネスロジックをユーザーに提示し、「この制約は新機能でも適用されるか？」と確認する（1問ずつ）
  3. **調査結果の記録** — 確認した影響範囲・業務ルールを設計書の「前提条件」「影響範囲」セクションに含める
- **自動遷移条件:** 設計書がコミット済み
- **成果物:** `docs/plans/*-design.md`
- **失敗時:** ユーザーが中断 -> STOP。クリーンアップ不要

### Phase 2: Spec Review

- **INVOKE:** `/spec-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `args` に `--codex` を、`--ui` 指定時は `--ui` を渡す（組み合わせ可能）
- **動作:** 設計書を4観点（requirements, design-judgment, feasibility, consistency）でレビューする
- **自動遷移条件:** レビュー全観点パス
- **成果物:** レビュー通過済み設計書
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、設計の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

### Phase 3: Plan

- **INVOKE:** `superpowers:writing-plans`
- **Autonomy:** AUTONOMOUS
- **動作:** レビュー通過済み設計書をもとに実装計画を作成する
- **自動遷移条件:** 計画書がコミット済み
- **成果物:** `docs/plans/*-plan.md`
- **失敗時:** 失敗内容を報告、PAUSE

### Phase 4: Plan Review

- **INVOKE:** `/implementation-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `args` に `--codex` を、`--ui` 指定時は `--ui` を渡す（組み合わせ可能）
- **動作:** 計画書を3観点（clarity, feasibility, consistency）でレビューする
- **自動遷移条件:** レビュー全観点パス
- **成果物:** レビュー通過済み計画書
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、計画の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

### Phase 5: Workspace

- **INVOKE:** `superpowers:using-git-worktrees`
- **Autonomy:** AUTONOMOUS+GATE
- **動作:** 開発用の worktree とブランチを作成する
- **自動遷移条件:** テスト通過
- **成果物:** worktree パス、ブランチ名
- **失敗時:** PAUSE。続行 or STOP を提案
- **GATE:** テスト失敗時に PAUSE

### Phase 6: Execute

- **INVOKE:** `superpowers:subagent-driven-development`
- **Autonomy:** AUTONOMOUS+GATE
- **動作:** レビュー通過済み計画書に基づき、サブエージェントで実装を実行する
- **自動遷移条件:** 全タスク完了
- **成果物:** コミット済みコード
- **失敗時:** 3回タスク失敗で PAUSE。設計ギャップをエスカレーション
- **GATE:** タスク失敗が累積した場合に PAUSE

### Phase 7: Code Review

- **INVOKE:** `/code-review`
- **Autonomy:** INTERACTIVE
- **`--codex` 伝播:** `--codex` 指定時、`/code-review` に `args: "--codex --branch"` を渡す
- **動作:** 実装コードを5観点（simplify, quality, security, performance, test）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** レビュー修正済みコード
- **失敗時:** 修正後テスト失敗 -> 最大2回リトライ、それでも失敗なら PAUSE
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

### Phase 8: Test Review

- **INVOKE:** `/test-review`
- **Autonomy:** INTERACTIVE
- **有効条件:** `--e2e` 指定時のみ。未指定時はスキップして Phase 9 へ
- **`--codex` 伝播:** `--codex` 指定時、`/test-review` に `args: "--codex"` を渡す
- **動作:** テストコードを2観点（coverage, quality）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** テストレビュー済みコード
- **失敗時:** テスト追加後の既存テスト破損 -> PAUSE。影響範囲を報告
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

### Phase 9: Integrate

- **INVOKE:** `superpowers:finishing-a-development-branch`
- **Autonomy:** INTERACTIVE
- **動作:** merge / PR / keep / discard のいずれかをユーザーに選択させる
- **自動遷移条件:** ユーザーの選択が完了
- **成果物:** merge 済みコード、または PR
- **失敗時:** マージコンフリクト -> コンフリクトを報告、手動解決を提案

## Handover

### タイミング

レビューフェーズ（Phase 2, 4, 7, 8）完了後は **必ず** `/handover` を実行する。他フェーズは context 状況に応じて任意。

Context が逼迫した場合は、どのフェーズであっても即座に `/handover` を実行する。

### パイプライン状態

`/handover` で保存する `project-state.json` に以下のパイプライン固有情報を含める:

```json
{
  "pipeline": "feature-dev",
  "current_phase": 3,
  "args": { "codex": true, "e2e": false },
  "artifacts": {
    "design_doc": "docs/plans/2026-03-06-xxx-design.md",
    "plan_doc": null,
    "worktree_path": null,
    "branch_name": null
  },
  "completed_phases": [1, 2],
  "review_history": {
    "spec_review": { "iterations": 2, "passed": true },
    "implementation_review": null
  }
}
```

### 再開

```
/continue -> handover.md を読み込み
    +-- pipeline: "feature-dev" を検出
    +-- current_phase から再開
    +-- args, artifacts を復元して次フェーズへ
```

## Phase Artifacts

| Phase | 成果物 | 消費者 |
|-------|--------|--------|
| 1 | `docs/plans/*-design.md` | Phase 2, 3 |
| 2 | レビュー通過済み設計書 | Phase 3 |
| 3 | `docs/plans/*-plan.md` | Phase 4, 6 |
| 4 | レビュー通過済み計画書 | Phase 6 |
| 5 | worktree パス、ブランチ名 | Phase 6, 9 |
| 6 | コミット済みコード | Phase 7, 8 |
| 7 | レビュー修正済みコード | Phase 8, 9 |
| 8 | テストレビュー済みコード | Phase 9 |

## Autonomy Summary

| Phase | Mode | 自動遷移 | GATE 条件 |
|-------|------|---------|-----------|
| 1: Design | INTERACTIVE | 設計書コミット済み | -- |
| 2: Spec Review | INTERACTIVE | レビュー全観点パス | -- |
| 3: Plan | AUTONOMOUS | 計画書コミット済み | -- |
| 4: Plan Review | INTERACTIVE | レビュー全観点パス | -- |
| 5: Workspace | AUTONOMOUS+GATE | テスト通過 | テスト失敗 -> PAUSE |
| 6: Execute | AUTONOMOUS+GATE | 全タスク完了 | 3回失敗 -> PAUSE |
| 7: Code Review | INTERACTIVE | 修正完了 | -- |
| 8: Test Review | INTERACTIVE | 修正完了 | -- |
| 9: Integrate | INTERACTIVE | 選択完了 | -- |

詳細は `references/autonomy-gates.md` を参照。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1: Design | ユーザーが中断 | STOP。クリーンアップ不要 |
| 2: Spec Review | エージェントエラー | 該当エージェントをスキップ、残りの結果で続行 |
| 2: Spec Review | 3回レビュー不合格 | PAUSE。設計の根本的見直しを提案 |
| 3: Plan | writing-plans 失敗 | 失敗内容を報告、PAUSE |
| 4: Plan Review | 3回レビュー不合格 | PAUSE。計画の根本的見直しを提案 |
| 5: Workspace | テスト失敗 | PAUSE。続行 or STOP を提案 |
| 6: Execute | 3回タスク失敗 | PAUSE。設計ギャップをエスカレーション |
| 7: Code Review | 修正後テスト失敗 | 最大2回リトライ、それでも失敗なら PAUSE |
| 8: Test Review | テスト追加後の既存テスト破損 | PAUSE。影響範囲を報告 |
| 9: Integrate | マージコンフリクト | コンフリクトを報告、手動解決を提案 |
| 全フェーズ | `--codex` 指定時に codex 未インストール | 警告し codex なしで続行 |
| 全フェーズ | Context 逼迫 | `/handover` を実行してパイプライン状態を保存 |

## Red Flags

**Never:**
- Phase 1（設計）をスキップする
- brainstorming の設計質問に自動回答する
- レビュー不合格をユーザー確認なしでパスさせる
- merge/PR/keep/discard をユーザーに代わって選択する
- テスト失敗のまま次フェーズに進む（ユーザー承認なし）
- レビュー findings を勝手にフィルタリング・省略する
- handover なしで context を使い切る

**Always:**
- Phase 遷移時に現在の Phase をアナウンスする
- レビューフェーズ完了後に `/handover` を実行する
- 成果物を次フェーズに引き継ぐ
- GATE 条件に該当したら PAUSE する
- 全エージェントの結果を待ってからレポートする
- 修正前にユーザーの選択を得る

## Integration

このオーケストレーターが invoke するスキル一覧:

| Phase | スキル | 種別 |
|-------|--------|------|
| 1 | `superpowers:brainstorming` | superpower |
| 2 | `/spec-review` | custom skill |
| 3 | `superpowers:writing-plans` | superpower |
| 4 | `/implementation-review` | custom skill |
| 5 | `superpowers:using-git-worktrees` | superpower |
| 6 | `superpowers:subagent-driven-development` | superpower |
| 7 | `/code-review` | custom skill |
| 8 | `/test-review` | custom skill |
| 9 | `superpowers:finishing-a-development-branch` | superpower |
| any | `/handover` | custom skill |
