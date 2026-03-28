---
name: feature-dev
description: >-
  品質ゲート付き開発オーケストレーター。9フェーズで設計→レビュー→計画→レビュー→
  実装→スモークテスト→コードレビュー→テストレビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Phase 8 (Test Review) を有効化。
  --smoke 指定時は Phase 6 (Smoke Test) を有効化。
  /tdd-orchestrate の後継。
  --iterations N 指定時は全レビューフェーズの N-way 投票回数を制御する（デフォルト: 3）。
user-invocable: true
---

# Feature Dev Orchestrator

9フェーズの superpowers スキルとカスタムレビュースキルを1セッション（複数セッション跨ぎ可）で順次 invoke し、feature spec から merge-ready なコードまでを品質ゲート付きで実行する。

**開始時アナウンス:** 「Feature Dev を開始します。Phase 1: Design」

## Input

`/feature-dev` の引数、または会話で提供された feature spec。最低要件: **何を作るか** + **なぜ作るか**。

feature spec が不足している場合はユーザーに確認する。推測で進めない。

## Arguments

| 引数 | 説明 |
|------|------|
| (なし) | 全フェーズ実行（Phase 6, 8 はスキップ） |
| `--codex` | 全レビューフェーズで Codex 並列レビューを有効化 |
| `--e2e` | Phase 8（Test Review）を有効化 |
| `--smoke` | Phase 6（Smoke Test）を有効化 |
| `--codex --e2e` | 組み合わせ可能 |
| `--ui` | Phase 2・Phase 4 に UI レビューエージェントを追加 |
| `--codex --e2e --smoke --ui` | 全組み合わせ可能 |
| `--iterations N` | 全レビューフェーズの N-way 投票回数を指定する（デフォルト: 3）。各レビュースキルにパススルーする |

## The Pipeline

```
Feature Spec
    |
    v
Phase 1: Design ──────── superpowers:brainstorming [INTERACTIVE]
    | 設計書ドラフト完成 -> worktree 作成 -> 設計書コミット -> 自動遷移
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
Phase 5: Execute ─────── superpowers:subagent-driven-development [AUTONOMOUS+GATE]
    | 全タスク完了 -> 自動遷移（--smoke 時は Phase 6 へ、それ以外は Phase 7 へ）
    v
Phase 6: Smoke Test ──── /smoke-test [--smoke 指定時 or UI自動検出時] [AUTONOMOUS+GATE]
    | PASS -> 自動遷移
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

## Audit Gate Protocol

各フェーズ完了後に Audit Gate を実行する。詳細は `./references/audit-gate-protocol.md` を参照。

### 共通手順（全フェーズ共通）
1. 成果物パスを `artifacts` に記録
2. `./done-criteria/phase-N-{name}.md` を Read で読み込む
3. Evidence Plan が存在する場合、該当アクティビティの collection 要件が Executor に注入済みか確認
4. Agent ツールで `phase-auditor` を起動（Audit Context を注入。テンプレートは `./references/audit-gate-protocol.md` セクション 2 参照）
5. 返却値の JSON 有効性を検証（不正なら1回再起動、2回目不正で PAUSE）
6. verdict に基づき遷移:
   - PASS: quality_warnings をユーザーに提示し次フェーズへ
   - FAIL + escalation: 即 PAUSE
   - FAIL + attempt < max_retries: Fix Dispatch → 再監査ループ
   - FAIL + attempt >= max_retries: 累積診断レポート提示 → PAUSE

### Phase 9: Audit Gate Lite
Phase 9 は Agent を起動せず、`./done-criteria/phase-9-integrate.md` の基準をオーケストレーターが直接検証。

### Evidence Plan 生成
Phase 1 Audit Gate 完了後に Evidence Plan を生成（phase-auditor が自動実行）。Phase 4 Audit Gate 完了後に再評価（設計書 hash 変更時のみ）。Evidence Plan は `docs/plans/` にコミットする。

### Evidence Collection（add-on）
Phase 5 以降の Executor 起動時、Evidence Plan から該当アクティビティの collection 要件を抽出しプロンプトに追加する。

### Phase 5 Re-gate + Re-review
Phase 7/8 でコード変更がある場合、Phase 7/8 の Audit Gate の前に:
1. git diff でコード変更を検知
2. Phase 5 Audit Gate を full mode で再実行
3. Phase 6 Audit Gate を再実行（--smoke 有効時）
4. /code-review（または /test-review）を再実行
5. findings があれば修正 → Step 2 に戻る
6. findings がなければ Phase 7/8 Audit Gate へ
詳細は `./references/audit-gate-protocol.md` セクション 8 を参照。

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

- **INVOKE 1:** Read tool で `./references/brainstorming-supplement.md`（このスキルのディレクトリからの相対パス）を読み込む（brainstorming の事前制約・追加ステップを context に載せる）
- **INVOKE 2:** 直後に Skill tool で `superpowers:brainstorming` を invoke する
- **INVOKE 3:** 設計書ドラフト完成後、コミット前に `superpowers:using-git-worktrees` を invoke し、開発用 worktree とブランチを作成する
- **Autonomy:** INTERACTIVE
- **動作:** supplement が先に context に載った状態で brainstorming を実行する。supplement により TaskCreate 禁止・インタラクティブ制約が適用され、clarifying questions 後に **並列探索エージェント（code-explorer + code-architect）を起動してコードベースをサブ context で深く調査** し、その結果をもとに暗黙ルール抽出・テスト観点列挙が実行される。設計書ドラフト完成後、worktree を作成し、ベースラインテスト通過後に設計書を worktree 内にコミットする
- **自動遷移条件:** worktree 作成済み かつ 設計書が worktree 内にコミット済み
- **成果物:** `docs/plans/*-design.md`、worktree パス、ブランチ名
- **失敗時:** ユーザーが中断 -> STOP。クリーンアップ不要
- **GATE:** worktree テスト失敗時に PAUSE。続行 or STOP をユーザーに提案

**Phase 1 完了 → Audit Gate**: `./done-criteria/phase-1-design.md` に基づき監査。activity_type: implementation。Evidence Plan 初回生成。

### Phase 2: Spec Review

- **INVOKE:** `/spec-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `args` に `--codex` を、`--ui` 指定時は `--ui` を、`--iterations N` は常に渡す（組み合わせ可能）
- **動作:** 設計書を4観点（requirements, design-judgment, feasibility, consistency）でレビューする
- **自動遷移条件:** レビュー全観点パス
- **成果物:** レビュー通過済み設計書
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、設計の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 2 完了 → Audit Gate**: `./done-criteria/phase-2-spec-review.md` に基づき監査。activity_type: review-fix。

### Phase 3: Plan

- **INVOKE:** `superpowers:writing-plans`
- **Autonomy:** AUTONOMOUS
- **動作:** レビュー通過済み設計書をもとに実装計画を作成する。設計書内の「テスト観点」セクションを `docs/plans/*-test-cases.md` に展開し、Given/When/Then レベルに詳細化する
- **自動遷移条件:** 計画書がコミット済み
- **成果物:** `docs/plans/*-plan.md`, `docs/plans/*-test-cases.md`
- **失敗時:** 失敗内容を報告、PAUSE

**Phase 3 完了 → Audit Gate**: `./done-criteria/phase-3-plan.md` に基づき監査。activity_type: implementation。

### Phase 4: Plan Review

- **INVOKE:** `/implementation-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `args` に `--codex` を、`--ui` 指定時は `--ui` を、`--iterations N` は常に渡す（組み合わせ可能）
- **動作:** 計画書を3観点（clarity, feasibility, consistency）でレビューする
- **自動遷移条件:** レビュー全観点パス
- **成果物:** レビュー通過済み計画書
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、計画の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 4 完了 → Audit Gate**: `./done-criteria/phase-4-plan-review.md` に基づき監査。activity_type: review-fix。Evidence Plan 再評価（設計書 hash 変更時）。

### Phase 5: Execute

- **INVOKE:** `superpowers:subagent-driven-development`
- **Autonomy:** AUTONOMOUS+GATE
- **TDD 注入:** `subagent-driven-development` が生成する各サブエージェントのプロンプトに、「実装コードを書く前に Skill tool で `superpowers:test-driven-development` を invoke せよ」という指示を含めること
- **動作:** レビュー通過済み計画書に基づき、サブエージェントで TDD プロセスに従って実装を実行する
- **自動遷移条件:** 全タスク完了
- **成果物:** コミット済みコード
- **失敗時:** 3回タスク失敗で PAUSE。設計ギャップをエスカレーション
- **GATE:** タスク失敗が累積した場合に PAUSE

**Phase 5 完了 → Audit Gate**: `./done-criteria/phase-5-execute.md` に基づき監査。activity_type: implementation。

### Phase 6: Smoke Test

- **INVOKE:** `/smoke-test`
- **Autonomy:** AUTONOMOUS+GATE
- **有効条件:** `--smoke` 指定時、または設計書に UI 関連キーワード（「画面」「UI」「ページ」「フォーム」「frontend」「component」「view」「page」「form」）が含まれる場合に自動有効化を提案（ユーザー確認あり）。未指定かつ UI 関連なしの場合はスキップして Phase 7 へ
- **引数伝播:** `args: "--diff-base <artifacts.branch_base> --design <artifacts.design_doc>"`
- **動作:** dev サーバーを起動し、Playwright でスモークテスト・VRT 差分チェック・E2E フレーキー検出を実行する
- **自動遷移条件:** smoke-test の終了ステータスが PASS
- **成果物:** `smoke-test-report.md`（一時ファイル）
- **失敗時:** FAIL → アプリケーションバグの修正を試行（最大2回）。修正不能なら PAUSE
- **GATE:** 終了ステータスが FAIL または PAUSE の場合に PAUSE

**Phase 6 完了 → Audit Gate**: `./done-criteria/phase-6-smoke-test.md` に基づき監査。activity_type: smoke-test。

### Phase 7: Code Review

- **INVOKE:** `/code-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す。例: `args: "--codex --branch --iterations 3"`
- **動作:** 実装コードを5観点（simplify, quality, security, performance, test）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** レビュー修正済みコード
- **失敗時:** 修正後テスト失敗 -> 最大2回リトライ、それでも失敗なら PAUSE
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 7 完了 → Audit Gate**: `./done-criteria/phase-7-code-review.md` に基づき監査。activity_type: review-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 8: Test Review

- **INVOKE:** `/test-review --design <artifacts.design_doc>`
- **Autonomy:** INTERACTIVE
- **有効条件:** `--e2e` 指定時のみ。未指定時はスキップして Phase 9 へ
- **`--design` 伝播:** `artifacts.design_doc`（Phase 1 の設計書パス）を `--design` 引数として自動付与する
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す（例: `args: "--design docs/plans/2026-03-11-xxx-design.md --codex --iterations 3"`）
- **動作:** テストコードを3観点（coverage, quality, design-alignment）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** テストレビュー済みコード
- **失敗時:** テスト追加後の既存テスト破損 -> PAUSE。影響範囲を報告
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 8 完了 → Audit Gate**: `./done-criteria/phase-8-test-review.md` に基づき監査。activity_type: test-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 9: Integrate

- **INVOKE:** `superpowers:finishing-a-development-branch`
- **Autonomy:** INTERACTIVE
- **動作:** merge / PR / keep / discard のいずれかをユーザーに選択させる
- **自動遷移条件:** ユーザーの選択が完了
- **成果物:** merge 済みコード、または PR
- **失敗時:** マージコンフリクト -> コンフリクトを報告、手動解決を提案

**Phase 9 完了 → Audit Gate Lite**: オーケストレーターが `./done-criteria/phase-9-integrate.md` を直接検証。

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
  "args": { "codex": true, "e2e": false, "iterations": 3 },
  "artifacts": {
    "design_doc": "docs/plans/2026-03-06-xxx-design.md",
    "plan_doc": null,
    "worktree_path": null,
    "branch_name": null,
    "smoke_test_report": null
  },
  "completed_phases": [1, 2],
  "review_history": {
    "spec_review": { "iterations": 2, "passed": true },
    "implementation_review": null
  }
}
```

### Handover State（Audit Gate 拡張）
pipeline state に以下を追加:
- `audit_state.current_attempt`: 現在の監査リトライ回数
- `audit_state.max_retries`: done-criteria の max_retries 値
- `audit_state.cumulative_diagnosis`: 累積診断 JSON 配列
- `audit_state.last_fix_dispatch`: 最後の Fix Dispatch 情報
- `artifacts.evidence_plan`: Evidence Plan ファイルパス

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
| 1 | `docs/plans/*-design.md`（テスト観点セクション含む）、worktree パス、ブランチ名 | Phase 2, 3, 5, 8, 9 |
| 2 | レビュー通過済み設計書 | Phase 3 |
| 3 | `docs/plans/*-plan.md`, `docs/plans/*-test-cases.md` | Phase 4, 5 |
| 4 | レビュー通過済み計画書 | Phase 5 |
| 5 | コミット済みコード | Phase 6, 7, 8 |
| 6 | `smoke-test-report.md`（一時ファイル） | Phase 7 |
| 7 | レビュー修正済みコード | Phase 8, 9 |
| 8 | テストレビュー済みコード | Phase 9 |

## Autonomy Summary

| Phase | Mode | 自動遷移 | GATE 条件 |
|-------|------|---------|-----------|
| 1: Design | INTERACTIVE | worktree 作成済み かつ 設計書コミット済み | テスト失敗 -> PAUSE |
| 2: Spec Review | INTERACTIVE | レビュー全観点パス | -- |
| 3: Plan | AUTONOMOUS | 計画書コミット済み | -- |
| 4: Plan Review | INTERACTIVE | レビュー全観点パス | -- |
| 5: Execute | AUTONOMOUS+GATE | 全タスク完了 | 3回失敗 -> PAUSE |
| 6: Smoke Test | AUTONOMOUS+GATE | PASS | FAIL/PAUSE -> PAUSE |
| 7: Code Review | INTERACTIVE | 修正完了 | -- |
| 8: Test Review | INTERACTIVE | 修正完了 | -- |
| 9: Integrate | INTERACTIVE | 選択完了 | -- |

詳細は Read tool で `./references/autonomy-gates.md`（このスキルのディレクトリからの相対パス）を読み込んで参照。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1: Design | ユーザーが中断 | STOP。クリーンアップ不要 |
| 1: Design | worktree テスト失敗 | PAUSE。続行 or STOP を提案 |
| 1: Design | 探索エージェント失敗 | soft failure。メイン context で Grep/Read にフォールバック |
| 2: Spec Review | エージェントエラー | 該当エージェントをスキップ、残りの結果で続行 |
| 2: Spec Review | 3回レビュー不合格 | PAUSE。設計の根本的見直しを提案 |
| 3: Plan | writing-plans 失敗 | 失敗内容を報告、PAUSE |
| 4: Plan Review | 3回レビュー不合格 | PAUSE。計画の根本的見直しを提案 |
| 5: Execute | 3回タスク失敗 | PAUSE。設計ギャップをエスカレーション |
| 6: Smoke Test | サーバー起動不可 | PAUSE。ユーザーに起動コマンドを確認 |
| 6: Smoke Test | スモークテスト失敗（修正可能） | 自動修正 → 再実行（最大2回） |
| 6: Smoke Test | スモークテスト失敗（修正不能） | PAUSE。ユーザーに報告 |
| 7: Code Review | 修正後テスト失敗 | 最大2回リトライ、それでも失敗なら PAUSE |
| 8: Test Review | テスト追加後の既存テスト破損 | PAUSE。影響範囲を報告 |
| 9: Integrate | マージコンフリクト | コンフリクトを報告、手動解決を提案 |
| 全フェーズ | `--codex` 指定時に MCP Codex 接続失敗 | 警告し codex なしで続行 |
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
| 1 | `superpowers:brainstorming`, `superpowers:using-git-worktrees` | superpower |
| 2 | `/spec-review` | custom skill |
| 3 | `superpowers:writing-plans` | superpower |
| 4 | `/implementation-review` | custom skill |
| 5 | `superpowers:subagent-driven-development`, `superpowers:test-driven-development` (サブエージェント内) | superpower |
| 6 | `/smoke-test` | custom skill |
| 7 | `/code-review` | custom skill |
| 8 | `/test-review` | custom skill |
| 9 | `superpowers:finishing-a-development-branch` | superpower |
| any | `/handover` | custom skill |
