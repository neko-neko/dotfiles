---
name: debug-flow
description: >-
  品質ゲート付きデバッグオーケストレーター。8フェーズで根本原因分析→修正計画→レビュー→
  実装→スモークテスト→コードレビュー→テストレビュー→統合を品質ゲート付きで実行する。
  systematic-debugging の調査プロセスを done-criteria + phase-auditor で品質管理し、
  feature-dev の後半パイプラインを踏襲する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Phase 7 (Test Review) を有効化。
  --smoke 指定時は Phase 5 (Smoke Test) を有効化。
  --iterations N 指定時は全レビューフェーズの N-way 投票回数を制御する（デフォルト: 3）。
  --swarm 指定時は Phase 1, 3, 6 でエージェントチームを使用する（デフォルト: false）。
  --linear 指定時は Linear チケットへの進捗同期を有効化する。
user-invocable: true
---

# Debug Flow Orchestrator

8フェーズの superpowers スキルとカスタムレビュースキルを1セッション（複数セッション跨ぎ可）で順次 invoke し、バグ報告から merge-ready な修正コードまでを品質ゲート付きで実行する。

**開始時アナウンス:** 「Debug Flow を開始します。Phase 1: Root Cause Analysis」

## Resume Gate（最優先で評価）

起動時に以下を確認:
1. `.claude/handover/` 配下に現在ブランチの READY セッションが存在するか
2. 複数 READY セッションがある場合、タイムスタンプ（fingerprint）が最新のものを選択
3. 存在する場合、`project-state.json` の `pipeline` が `"debug-flow"` と一致するか

一致する場合 → **Resume Mode** で起動する（Phase 1 からの通常フローをスキップ）。
一致しない場合 → 通常の新規起動。

### Resume Mode 実行フロー

1. `project-state.json` を読み込む
2. `args` からフラグを復元する（`--codex`, `--e2e`, `--smoke`, `--ui`, `--iterations`, `--swarm`, `--linear`）
   - `--linear`: `project-state.json` の `linear_ticket_id` が存在する場合に自動復元。`linear_document_id` も復元する。
3. `phase_observations[]` + `session_notes[]` から soft context を表示する:
   - `relates_to_phase` が `current_phase` 以降 → 全件表示
   - `relates_to_phase` が `current_phase` より前 → `directive` / `concern` のみ
   - 表示順: directive → concern → insight → quality → warning
4. 再開位置を表示し、ユーザー承認を得る:
   ```
   Pipeline: debug-flow ({復元されたフラグ})
   現在: Phase {N} {name}（{status}）

   [前セッションからの引き継ぎ]
   - ⚠ {session_notes / phase_observations の要約}

   [監査状態]
   - Phase {N} Audit: {状態} / attempt {M} of {max_retries}

   この状態から再開します。よろしいですか？
   ```
5. 承認後、`current_phase` のフェーズから作業を続行する
6. 以降は通常のフェーズ遷移ルール・監査ゲートに従う

### フェーズ途中 vs フェーズ間の再開

- **フェーズ途中**（`active_tasks` に `in_progress` あり）: 残タスクから再開。完了時に done-criteria で監査
- **フェーズ間**（前フェーズ完了、次フェーズ未開始）: 前フェーズの監査ゲートが PASS 済みか確認。未実施なら監査から実行

### Resume Mode で「やらないこと」

- Phase 1 からのやり直し（`completed_phases` はスキップ）
- 完了済みフェーズの再監査（コミット SHA が git log に存在すれば信頼）
- 新規起動時の引数パース（`args` は `project-state.json` から復元）

<HARD-GATE>
## Mandatory Audit Gate — フェーズ遷移の絶対条件

フェーズ遷移は Audit Gate を経由しなければならない。例外なし。

各フェーズの作業完了後、次フェーズへ遷移する前に:
1. `./done-criteria/phase-N-{name}.md` を Read で読み込む
2. frontmatter の `audit` フィールドを確認する
3. `audit: required` → phase-auditor を Agent ツールで起動し、PASS verdict を得る
4. `audit: lite` → オーケストレーターが done-criteria の基準を直接検証する
5. `audit` 未定義 → `required` として扱う

以下はスキップの理由にならない:
- 「前のフェーズで十分に検証した」
- 「シンプルな変更だから不要」
- 「レビュースキルが既に品質を確認した」
- 「時間/トークンを節約したい」

phase-auditor の verdict なしに Phase N+1 のアナウンスや作業開始を行った場合、
それは**プロトコル違反**である。
</HARD-GATE>

## Input

`/debug-flow` の引数、または会話で提供されたバグ報告/症状。最低要件: **何が起きているか**（エラーメッセージ、異常動作）+ **再現手順**（可能な範囲）。

入力が不足している場合はユーザーに確認する。推測で進めない。

## Arguments

| 引数 | 説明 |
|------|------|
| (なし) | Phase 1〜4, 6, 8 を実行（Phase 5, 7 はスキップ） |
| `--codex` | 全レビューフェーズで Codex 並列レビューを有効化 |
| `--e2e` | Phase 7（Test Review）を有効化 |
| `--smoke` | Phase 5（Smoke Test）を有効化 |
| `--codex --e2e` | 組み合わせ可能 |
| `--ui` | Phase 3 に UI レビューエージェントを追加 |
| `--codex --e2e --smoke --ui` | 全組み合わせ可能 |
| `--iterations N` | 全レビューフェーズの N-way 投票回数を指定する（デフォルト: 3）。各レビュースキルにパススルーする。`--swarm` 有効時は Phase 3, 6 で無視される |
| `--swarm` | Phase 1, 3, 6 でエージェントチーム（TeamCreate）を使用する。Audit Gate も Audit Team 化。メンバー間の直接通信・相互検証・議論ベース合意形成を有効化。デフォルト: false |
| `--linear` | Linear チケットへの進捗同期を有効化。`linear-sync` supplement skill を起動し、各フェーズ完了後に Linear へ同期する。 |

## The Pipeline

```
Bug Report / Symptom
    |
    v
Phase 1: Root Cause Analysis ── 並列探索 + 根本原因特定 + 仮説検証 [AUTONOMOUS+GATE]
    | 根本原因特定 + 再現テスト作成 -> 自動遷移
    v
Phase 2: Fix Plan ────────────── superpowers:writing-plans [AUTONOMOUS]
    | 修正計画コミット済み -> 自動遷移
    v
Phase 3: Fix Plan Review ─────── /implementation-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    | 不合格 -> ユーザーヒアリング -> 修正 -> 再レビュー
    v
Phase 4: Execute ──────────────── superpowers:subagent-driven-development [AUTONOMOUS+GATE]
    | 全タスク完了 -> 自動遷移
    v
Phase 5: Smoke Test ───────────── /smoke-test [--smoke 指定時] [AUTONOMOUS+GATE]
    | PASS -> 自動遷移
    v
Phase 6: Code Review ──────────── /code-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 7: Test Review ──────────── /test-review [--e2e 指定時のみ] [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 8: Integrate ────────────── worktrunk:worktrunk [INTERACTIVE]
    |
    v
  Complete
```

## Audit Gate Protocol

各フェーズ完了後に Audit Gate を実行する。以下はクイックリファレンス。完全な仕様は `./references/audit-gate-protocol.md` を参照。

### 共通手順（全フェーズ共通）
1. 成果物パスを `artifacts` に記録
2. `./done-criteria/phase-N-{name}.md` を Read で読み込む
3. Evidence Plan が存在する場合、該当アクティビティの collection 要件が Executor に注入済みか確認
4. Audit Agent を起動（`--swarm` 有効時は Audit Team。詳細は後述「Audit Team」セクション + `./references/audit-gate-protocol.md` セクション 2, 10 参照）
5. 返却値の JSON 有効性を検証（不正なら1回再起動、2回目不正で PAUSE）
6. verdict に基づき遷移:
   - PASS: quality_warnings をユーザーに提示し、`observations[]` を `project-state.json` の `phase_observations[]` に追記し、次フェーズへ
   - FAIL + escalation: 即 PAUSE
   - FAIL + attempt < max_retries: Fix Dispatch → 再監査ループ
   - FAIL + attempt >= max_retries: 累積診断レポート提示 → PAUSE

### Linear Sync（`--linear` 有効時、全フェーズ共通）

Audit Gate 完了後、次フェーズへの遷移前に実行:

1. phase_result を構造化:
   - `phase`: 現在のフェーズ番号
   - `phase_name`: フェーズ名
   - `verdict`: Audit Gate の verdict（PASS/FAIL）またはフェーズ固有の結果
   - `summary`: フェーズの成果要約
   - `test_results`: テスト実行結果（該当フェーズのみ。Phase 4, 5）
   - `audit_observations`: phase-auditor の observations（audit: required のフェーズ）
   - `evidence_files`: アップロード対象ファイル（RCA Report, スクリーンショット等）
2. `claude/skills/linear-sync/SKILL.md` の `sync_phase` セクションの手順に従い実行
3. API 失敗時はワークフローをブロックせず続行

### Audit Team（`--swarm` 有効時）
`--swarm` 有効時、inspection 基準を含む Phase 1-7 の Audit Gate をエージェントチーム（3メンバー: automated-verifier, inspection-verifier, evidence-verifier）で実行する。メンバー間で findings を相互検証し、合意した verdict を返却する。Phase 8 は automated のみのため単一エージェント。詳細は `./references/audit-gate-protocol.md` セクション 10 を参照。

### Phase 8: Audit Gate Lite
Phase 8 は Agent を起動せず、`./done-criteria/phase-8-integrate.md` の基準をオーケストレーターが直接検証。

### Evidence Plan 生成（正規定義はここ。protocol には消費ロジックのみ）
Phase 1 Audit Gate 完了後に Evidence Plan を生成（phase-auditor が自動実行）。Evidence Plan は `docs/plans/` にコミットする。

### Evidence Collection（add-on）
Phase 4 以降の Executor 起動時、Evidence Plan から該当アクティビティの collection 要件を抽出しプロンプトに追加する。

### Phase 4 Re-gate + Re-review
Phase 6/7 でコード変更がある場合、Phase 6/7 の Audit Gate の前に:
1. git diff でコード変更を検知
2. Phase 4 Audit Gate を full mode で再実行
3. Phase 5 Audit Gate を再実行（--smoke 有効時）
4. /code-review（または /test-review）を再実行
5. findings があれば修正 → Step 2 に戻る
6. findings がなければ Phase 6/7 Audit Gate へ
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
trace_phase_start "$TRACE_FILE" "debug-flow" <phase_number> "<phase_name>"
```

**Phase 終了時（次の Phase に遷移する直前、または pipeline 終了時）:**
```bash
source ~/.dotfiles/claude/skills/handover/scripts/trace-lib.sh
TRACE_SESSION_ID="${SESSION_ID:-unknown}"
duration_ms=$(( $(date +%s%3N) - phase_start_time ))
trace_phase_end "$TRACE_FILE" "debug-flow" <phase_number> "<phase_name>" $duration_ms
```

### リトライ時

レビュー不合格→修正→再レビューが発生した場合:
```bash
trace_retry "$TRACE_FILE" "debug-flow" <phase_number> <attempt> "<reason>"
```

### Linear Sync 初期化（`--linear` 有効時のみ）

1. `claude/skills/linear-sync/SKILL.md` を Read
2. `resolve_ticket` セクションの手順に従いチケットを特定
3. チケット確定後、`sync_workflow_start` セクションの手順に従い Document 作成・開始コメント投稿
4. `linear_ticket_id` と `linear_document_id` をワークフローコンテキストに保持

## Phase Details

### Phase 1: Root Cause Analysis

systematic-debugging の Phase 1（Root Cause Investigation）、Phase 2（Pattern Analysis）、Phase 3（Hypothesis and Testing）を統合したフェーズ。

- **Autonomy:** AUTONOMOUS+GATE
- **動作:**
  1. **症状の構造化:** エラーメッセージ、スタックトレース、再現手順を整理
  2. **並列探索エージェント起動:**
     - `code-explorer`: 障害箇所のコードフロー（entry point → データ層）をトレース
     - `code-architect`: 関連するアーキテクチャパターン・制約・暗黙ルールを抽出
     - `impact-analyzer`: 障害箇所からの逆方向依存追跡、副作用リスクの特定
  3. **探索結果の統合 → 根本原因の特定:**
     - 各エージェントの結果を統合し、仮説を立案
     - systematic-debugging の原則に従い、**1つの仮説を最小変更で検証**
     - 仮説が棄却された場合、新仮説を立案（最大3回。3回失敗でアーキテクチャ問題として PAUSE）
  4. **再現テスト作成:** 根本原因を証明する最小再現テスト（failing test）を作成
  5. **RCA Report 作成:** 調査結果を構造化文書にまとめる（構造は後述）
  6. **worktree 作成:** `worktrunk:worktrunk` を invoke し、`wt switch -c <branch> [-b <base>]` で修正用 worktree とブランチを作成。ベースブランチはコンテキストから判断する（`/continue` 時は handover の記録から復元）
  7. **コミット:** RCA Report と再現テストを worktree 内にコミット
- **`--swarm` 有効時（Investigation Team）:**
  並列探索をサブエージェントではなくエージェントチームで実行する。
  1. TeamCreate で Investigation Team を作成（チーム名: `investigation-{bug}`）
  2. メンバー: code-explorer, code-architect, impact-analyzer の3エージェント
  3. メンバー間通信を有効化: Explorer の発見 → Architect がパターン分析 → Impact が依存先を深掘り
  4. 共有タスク: RCA Report の Investigation Record 各セクション（Code Flow Trace, Architecture Context, Impact Scope）をタスクとして割り当て
  5. チーム完了後、結果を統合して仮説立案に進む
- **自動遷移条件:** RCA Report コミット済み かつ 再現テスト FAIL
- **成果物:** `docs/debug/YYYY-MM-DD-{bug}-rca.md`、再現テストファイル、worktree パス、ブランチ名
- **失敗時:** 探索エージェント失敗 → soft failure。メイン context で Grep/Read にフォールバック
- **GATE:** 仮説検証3回失敗 → PAUSE（アーキテクチャ問題エスカレーション）
- **GATE:** 再現テスト作成不可 → PAUSE（手動再現を提案）
- **GATE:** worktree テスト失敗 → PAUSE。続行 or STOP をユーザーに提案

#### RCA Report 構造

```markdown
## 1. Symptom（症状）
- エラーメッセージ / 異常動作の記述
- 再現手順

## 2. Investigation Record（調査記録）
### 2.1 Code Flow Trace（コードフロートレース）
- entry point → 障害箇所までのコールチェーン
- 各レイヤーでのデータ変換・状態変化

### 2.2 Architecture Context（アーキテクチャ制約）
- 関連するパターン・規約・暗黙ルール
- 該当コンポーネントの設計意図

### 2.3 Impact Scope（影響範囲）
- 逆方向依存ファイル一覧
- 副作用リスク
- 共有状態

### 2.4 Symmetry Check（対称性検証）
- 変更対象の計算が「対」を持つか（持たない場合はその根拠）
- 対となるパス一覧（ファイルパス、関数名、pair type）
- フィルタ/スコープ条件の対称性（同一条件が両パスに適用されているか）
- 同一データを公開するコンシューマ一覧（画面、API、レポート等）と各計算パス
- 非対称性リスク（片側のみ変更した場合に発生しうる不整合）

### 2.5 Excluded Hypotheses（除外した仮説）
- 仮説、検証方法、棄却理由（1件以上必須）

## 3. Root Cause（根本原因）
- 原因の特定（ファイルパス、行番号、メカニズム）
- 根拠（コードフロー + エビデンス）

## 4. Reproduction Test（再現テスト）
- テストファイルパス
- テスト実行結果（FAIL であること）

## 5. Fix Strategy（修正方針）
- 修正対象ファイル・関数
- 修正アプローチ（概要）
- 影響範囲の予測
```

**Phase 1 完了 → Audit Gate**: `./done-criteria/phase-1-rca.md` に基づき監査。activity_type: investigation。Evidence Plan 初回生成。

### Phase 2: Fix Plan

- **INVOKE:** `superpowers:writing-plans`
- **Autonomy:** AUTONOMOUS
- **動作:** RCA Report をもとに修正計画を作成する。RCA Report 内の Fix Strategy セクションを `docs/plans/*-fix-plan.md` に展開し、テストケースも `docs/plans/*-test-cases.md` に詳細化する
- **自動遷移条件:** 計画書がコミット済み
- **成果物:** `docs/plans/*-fix-plan.md`, `docs/plans/*-test-cases.md`
- **失敗時:** 失敗内容を報告、PAUSE

**Phase 2 完了 → Audit Gate**: `./done-criteria/phase-2-fix-plan.md` に基づき監査。activity_type: implementation。

### Phase 3: Fix Plan Review

- **INVOKE:** `/implementation-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `args` に `--codex` を、`--ui` 指定時は `--ui` を、`--iterations N` は常に渡す（組み合わせ可能）
- **動作:** 修正計画を3観点（clarity, feasibility, consistency）でレビューする
- **`--swarm` 有効時（Plan Review Team）:**
  `/implementation-review` の代わりにエージェントチームでレビューを実行する。`--iterations` は無視される。
  1. TeamCreate で Plan Review Team を作成（チーム名: `plan-review-{bug}`）
  2. メンバー: implementation-review-clarity, implementation-review-feasibility, implementation-review-consistency の3エージェント
  3. consistency エージェントには RCA Report パスを追加コンテキストとして渡し、RCA → 計画の整合性を検証
  4. 各メンバーが自身の観点でレビュー後、他メンバーの findings を相互検証
  5. 矛盾する findings はメンバー間の議論で解決
  6. チーム完了後、統合結果をユーザーに提示
- **自動遷移条件:** レビュー全観点パス（チームモード時: チーム合意で findings なし）
- **成果物:** レビュー通過済み修正計画
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、計画の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 3 完了 → Audit Gate**: `./done-criteria/phase-3-fix-plan-review.md` に基づき監査。activity_type: review-fix。

### Phase 4: Execute

- **INVOKE:** `superpowers:subagent-driven-development`
- **Autonomy:** AUTONOMOUS+GATE
- **実装エージェント:** `subagent-driven-development` が生成する各実装サブエージェントは `subagent_type: "feature-implementer"` で起動すること。`feature-implementer` は `skills: [superpowers:test-driven-development]` を frontmatter で宣言しており、TDD スキルがコンテキストに自動注入される。
- **動作:** レビュー通過済み修正計画に基づき、`feature-implementer` エージェントが TDD プロセスに従って修正を実行する
- **自動遷移条件:** 全タスク完了
- **成果物:** コミット済みコード
- **失敗時:** 3回タスク失敗で PAUSE。RCA ギャップをエスカレーション
- **GATE:** タスク失敗が累積した場合に PAUSE

**Phase 4 完了 → Audit Gate**: `./done-criteria/phase-4-execute.md` に基づき監査。activity_type: implementation。

### Phase 5: Smoke Test

- **INVOKE:** `/smoke-test`
- **Autonomy:** AUTONOMOUS+GATE
- **有効条件:** `--smoke` 指定時。未指定時はスキップして Phase 6 へ
- **引数伝播:** `args: "--diff-base <artifacts.branch_base> --design <artifacts.rca_report>"`
- **動作:** dev サーバーを起動し、Playwright でスモークテスト・VRT 差分チェック・E2E フレーキー検出を実行する
- **自動遷移条件:** smoke-test の終了ステータスが PASS
- **成果物:** `smoke-test-report.md`（一時ファイル）
- **失敗時:** FAIL → アプリケーションバグの修正を試行（最大2回）。修正不能なら PAUSE
- **GATE:** 終了ステータスが FAIL または PAUSE の場合に PAUSE

**Phase 5 完了 → Audit Gate**: `./done-criteria/phase-5-smoke-test.md` に基づき監査。activity_type: smoke-test。

### Phase 6: Code Review

- **INVOKE:** `/code-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す。例: `args: "--codex --branch --iterations 3"`
- **動作:** 修正コードを7観点（simplify, quality, security, performance, test, ai-antipattern, impact）でレビューする
- **`--swarm` 有効時（Code Review Team）:**
  `/code-review` の代わりにエージェントチームでレビューを実行する。`--iterations` は無視される。
  1. TeamCreate で Code Review Team を作成（チーム名: `code-review-{bug}`）
  2. メンバー: code-review-quality, code-review-security, code-review-performance, code-review-test, code-review-ai-antipattern, code-review-impact の6エージェント
  3. simplify は Skill tool で Leader が別途実行（チーム外）
  4. code-review-impact には RCA Report の Impact Scope セクションを追加コンテキストとして渡す
  5. 各メンバーがレビュー後、他メンバーの findings を相互検証
  6. チーム完了後、統合結果をユーザーに提示
- **Impact Findings 延期制限:**
  code-review-impact（または impact エージェント）が severity: high 以上の finding を報告した場合、
  オーケストレーターはその finding を自動的に延期・却下してはならない。
  以下のいずれかをユーザーに明示的に確認する:
  1. **修正する**: finding に従い修正を実施
  2. **延期する**: ユーザーが影響を理解した上で明示的に承認（承認理由を記録）
  3. **却下する**: 誤検出の根拠をユーザーに提示し、ユーザーが却下を承認

  オーケストレーターの自己判断による延期は禁止。
  `--swarm` 有効時の Code Review Team でも同様に適用する。
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** レビュー修正済みコード
- **失敗時:** 修正後テスト失敗 -> 最大2回リトライ、それでも失敗なら PAUSE
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 6 完了 → Audit Gate**: `./done-criteria/phase-6-code-review.md` に基づき監査。activity_type: review-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 7: Test Review

- **INVOKE:** `/test-review --design <artifacts.rca_report>`
- **Autonomy:** INTERACTIVE
- **有効条件:** `--e2e` 指定時のみ。未指定時はスキップして Phase 8 へ
- **`--design` 伝播:** `artifacts.rca_report`（Phase 1 の RCA Report パス）を `--design` 引数として自動付与する
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す（例: `args: "--design docs/debug/2026-03-28-xxx-rca.md --codex --iterations 3"`）
- **動作:** テストコードを3観点（coverage, quality, design-alignment）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** テストレビュー済みコード
- **失敗時:** テスト追加後の既存テスト破損 -> PAUSE。影響範囲を報告
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 7 完了 → Audit Gate**: `./done-criteria/phase-7-test-review.md` に基づき監査。activity_type: test-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 8: Integrate

- **INVOKE:** `worktrunk:worktrunk`（`wt merge` 選択時）
- **Autonomy:** INTERACTIVE
- **動作:** 以下の4オプションをユーザーに提示し、選択に従い実行する:
  1. **`wt merge`**: `worktrunk` スキルを invoke → `wt merge` 実行。スカッシュ→リベース→FF マージ→worktree 削除を一括処理。pre-merge フックでテスト・ビルド検証が自動実行される
  2. **PR 作成**: `git push -u` + `gh pr create` で PR を作成。PR 作成後に `wt remove` で worktree を削除
  3. **ブランチ保持**: 何もしない。worktree もブランチもそのまま保持
  4. **破棄**: `wt remove` で worktree とブランチを削除
- **自動遷移条件:** ユーザーの選択が完了
- **成果物:** merge 済みコード、PR、またはブランチ保持/破棄の確認
- **失敗時:** マージコンフリクト -> コンフリクトを報告、手動解決を提案

**Phase 8 完了 → Audit Gate Lite**: オーケストレーターが `./done-criteria/phase-8-integrate.md` を直接検証。

### Linear Sync 完了（`--linear` 有効時のみ）

全フェーズ完了後:
1. `claude/skills/linear-sync/SKILL.md` の `sync_complete` セクションの手順に従い実行
2. Document 最終更新、完了コメント投稿、ステータス更新

## Handover

### タイミング

レビューフェーズ（Phase 3, 6, 7）完了後は **必ず** `/handover` を実行する。他フェーズは context 状況に応じて任意。

Context が逼迫した場合は、どのフェーズであっても即座に `/handover` を実行する。

### Session Notes Collection（handover 前の必須ステップ）

`/handover` invoke 前に、以下の3カテゴリで `project-state.json` の `session_notes[]` に記録すること。
該当なしの場合は記録不要（空振り OK）。

#### insight（調査洞察）
- 棄却した仮説から得られた副次的発見
- 実装中に気づいたが今のフェーズのスコープ外だった問題
- コードベース探索で得た、設計書に書かれていない暗黙の制約

#### directive（次セッション指示）
- 次フェーズで重点的に確認すべき観点
- フラグやオプションに関する補足
- 特定のファイル・モジュールへの注意喚起

#### concern（品質懸念）
- 動作するが設計的に不安な箇所
- テストのフレーキーリスク
- パフォーマンス・セキュリティの潜在的問題

### パイプライン状態

`/handover` で保存する `project-state.json` に以下のパイプライン固有情報を含める:

```json
{
  "pipeline": "debug-flow",
  "current_phase": 2,
  "args": { "codex": false, "e2e": false, "smoke": false, "ui": false, "iterations": 3, "swarm": false, "linear": false },
  "linear_ticket_id": null,
  "linear_document_id": null,
  "artifacts": {
    "rca_report": "docs/debug/2026-03-28-xxx-rca.md",
    "fix_plan": null,
    "reproduction_test": "tests/xxx_test.py",
    "worktree_path": "/path/to/worktree",
    "branch_name": "fix/xxx"
  },
  "completed_phases": [1],
  "audit_state": {
    "current_attempt": 1,
    "max_retries": 3,
    "cumulative_diagnosis": [],
    "last_fix_dispatch": null
  },
  "review_history": {
    "fix_plan_review": null,
    "code_review": null,
    "test_review": null
  },
  "phase_observations": [],
  "session_notes": []
}
```

### 再開

```
/continue -> handover.md を読み込み
    +-- pipeline: "debug-flow" を検出
    +-- current_phase から再開
    +-- args, artifacts を復元して次フェーズへ
```

## Phase Artifacts

| Phase | 成果物 | 消費者 |
|-------|--------|--------|
| 1 | `docs/debug/*-rca.md`、再現テスト、worktree パス、ブランチ名 | Phase 2, 4, 6, 7, 8 |
| 2 | `docs/plans/*-fix-plan.md`, `docs/plans/*-test-cases.md` | Phase 3, 4 |
| 3 | レビュー通過済み修正計画 | Phase 4 |
| 4 | コミット済みコード | Phase 5, 6, 7 |
| 5 | `smoke-test-report.md`（一時ファイル） | Phase 6 |
| 6 | レビュー修正済みコード | Phase 7, 8 |
| 7 | テストレビュー済みコード | Phase 8 |

## Autonomy Summary

| Phase | Mode | 自動遷移 | GATE 条件 |
|-------|------|---------|-----------|
| 1: RCA | AUTONOMOUS+GATE | RCA Report コミット済み + 再現テスト FAIL | 仮説3回失敗 → PAUSE |
| 2: Fix Plan | AUTONOMOUS | 計画書コミット済み | -- |
| 3: Fix Plan Review | INTERACTIVE | レビュー全観点パス | -- |
| 4: Execute | AUTONOMOUS+GATE | 全タスク完了 | 3回失敗 → PAUSE |
| 5: Smoke Test | AUTONOMOUS+GATE | PASS | FAIL/PAUSE → PAUSE |
| 6: Code Review | INTERACTIVE | 修正完了 | -- |
| 7: Test Review | INTERACTIVE | 修正完了 | -- |
| 8: Integrate | INTERACTIVE | 選択完了 | -- |

詳細は Read tool で `./references/autonomy-gates.md`（このスキルのディレクトリからの相対パス）を読み込んで参照。

## Error Handling

| フェーズ | エラー | リカバリ |
|---------|--------|---------|
| 1: RCA | 探索エージェント失敗 | soft failure。メイン context で Grep/Read にフォールバック |
| 1: RCA | 仮説検証3回失敗 | PAUSE。アーキテクチャ問題をエスカレーション |
| 1: RCA | 再現テスト作成不可 | PAUSE。手動再現を提案 |
| 1: RCA | worktree テスト失敗 | PAUSE。続行 or STOP を提案 |
| 2: Fix Plan | writing-plans 失敗 | 失敗内容を報告、PAUSE |
| 3: Fix Plan Review | 3回レビュー不合格 | PAUSE。計画の根本的見直しを提案 |
| 3: Fix Plan Review | エージェントエラー | 該当エージェントをスキップ、残りの結果で続行 |
| 4: Execute | 3回タスク失敗 | PAUSE。RCA ギャップをエスカレーション |
| 5: Smoke Test | サーバー起動不可 | PAUSE。ユーザーに起動コマンドを確認 |
| 5: Smoke Test | テスト失敗（修正可能） | 自動修正 → 再実行（最大2回） |
| 5: Smoke Test | テスト失敗（修正不能） | PAUSE。ユーザーに報告 |
| 6: Code Review | 修正後テスト失敗 | 最大2回リトライ、それでも失敗なら PAUSE |
| 7: Test Review | 既存テスト破損 | PAUSE。影響範囲を報告 |
| 8: Integrate | マージコンフリクト | コンフリクトを報告、手動解決を提案 |
| 全フェーズ | `--codex` 指定時に Codex 接続失敗 | 警告し codex なしで続行 |
| 全フェーズ | Context 逼迫 | `/handover` を実行してパイプライン状態を保存 |

## Red Flags

**Never:**
- Phase 1（RCA）をスキップする
- 根本原因を特定せずに修正に進む
- 再現テストなしで修正を開始する
- レビュー不合格をユーザー確認なしでパスさせる
- merge/PR/keep/discard をユーザーに代わって選択する
- テスト失敗のまま次フェーズに進む（ユーザー承認なし）
- レビュー findings を勝手にフィルタリング・省略する
- handover なしで context を使い切る

**Always:**
- Phase 遷移時に現在の Phase をアナウンスする
- レビューフェーズ完了後に `/handover` を実行する
- RCA Report の成果物を後続フェーズに引き継ぐ
- GATE 条件に該当したら PAUSE する
- 全エージェントの結果を待ってからレポートする
- 修正前にユーザーの選択を得る

## Integration

このオーケストレーターが invoke するスキル一覧:

| Phase | スキル | 種別 |
|-------|--------|------|
| 1 | `worktrunk:worktrunk` | plugin |
| 2 | `superpowers:writing-plans` | superpower |
| 3 | `/implementation-review` | custom skill |
| 4 | `superpowers:subagent-driven-development` + `feature-implementer` agent (TDD skills 自動注入) | superpower + agent |
| 5 | `/smoke-test` | custom skill |
| 6 | `/code-review` | custom skill |
| 7 | `/test-review` | custom skill |
| 8 | `worktrunk:worktrunk`（+ `gh` for PR） | plugin |
| any | `/handover` | custom skill |
