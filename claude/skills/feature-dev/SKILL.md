---
name: feature-dev
description: >-
  品質ゲート付き開発オーケストレーター。10フェーズで設計→レビュー→計画→レビュー→
  実装→ドキュメント監査→スモークテスト→コードレビュー→テストレビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Phase 9 (Test Review) を有効化。
  --smoke 指定時は Phase 7 (Smoke Test) を有効化。
  --doc 指定時は Phase 6 (Doc Audit) を有効化。
  /tdd-orchestrate の後継。
  --iterations N 指定時は全レビューフェーズの N-way 投票回数を制御する（デフォルト: 3）。
  --swarm 指定時は Phase 1, 2, 4, 8 でエージェントチームを使用する（デフォルト: false）。
  --linear 指定時は Linear チケットへの進捗同期を有効化する。
user-invocable: true
---

# Feature Dev Orchestrator

10フェーズの superpowers スキルとカスタムレビュースキルを1セッション（複数セッション跨ぎ可）で順次 invoke し、feature spec から merge-ready なコードまでを品質ゲート付きで実行する。

**開始時アナウンス:** 「Feature Dev を開始します。Phase 1: Design」

## Coordinator Discipline

このワークフローのオーケストレーターは、subagent の findings を受け取って次の作業へ流す前に、自身で理解・統合する責務を持つ。

- デフォルトの進め方は Research → Synthesis → Implementation → Verification
- subagent prompt は自己完結にする。目的、対象、完了条件、検証方法を含め、`based on your findings` のような委譲表現は禁止する
- read-only な探索や独立観点のレビューは並列化し、同一 write scope の実装・修正は直列化する
- 失敗修正や直前作業の継続は同一エージェント continuation を優先し、独立 verification や方針変更時は fresh context を使う
- non-trivial な実装は、実装担当とは独立した verification を通してから完了扱いにする

## Resume Gate（最優先で評価）

起動時に以下を確認:
1. `.agents/handover/` 配下に現在ブランチの READY セッションが存在するか
2. 複数 READY セッションがある場合、タイムスタンプ（fingerprint）が最新のものを選択
3. 存在する場合、`project-state.json` の `pipeline` が `"feature-dev"` と一致するか

一致する場合 → **Resume Mode** で起動する（Phase 1 からの通常フローをスキップ）。
一致しない場合 → 通常の新規起動。

### Resume Mode 実行フロー

1. `project-state.json` を読み込む
2. `args` からフラグを復元する（`--codex`, `--e2e`, `--smoke`, `--doc`, `--ui`, `--iterations`, `--swarm`, `--linear`）
   - `--linear`: `project-state.json` の `linear_ticket_id` が存在する場合に自動復元。`linear_document_id` も復元する。
3. `phase_observations[]` + `session_notes[]` から soft context を表示する:
   - `relates_to_phase` が `current_phase` 以降 → 全件表示
   - `relates_to_phase` が `current_phase` より前 → `directive` / `concern` のみ
   - 表示順: directive → concern → insight → quality → warning
4. 再開位置を表示し、ユーザー承認を得る:
   ```
   Pipeline: feature-dev ({復元されたフラグ})
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

`/feature-dev` の引数、または会話で提供された feature spec。最低要件: **何を作るか** + **なぜ作るか**。

feature spec が不足している場合はユーザーに確認する。推測で進めない。

## Arguments

| 引数 | 説明 |
|------|------|
| (なし) | 全フェーズ実行（Phase 6, 7, 9 はスキップ） |
| `--codex` | 全レビューフェーズで Codex 並列レビューを有効化 |
| `--e2e` | Phase 9（Test Review）を有効化 |
| `--smoke` | Phase 7（Smoke Test）を有効化 |
| `--doc` | Phase 6（Doc Audit）を有効化 |
| `--codex --e2e` | 組み合わせ可能 |
| `--ui` | Phase 2・Phase 4 に UI レビューエージェントを追加 |
| `--codex --e2e --smoke --doc --ui` | 全組み合わせ可能 |
| `--iterations N` | 全レビューフェーズの N-way 投票回数を指定する（デフォルト: 3）。各レビュースキルにパススルーする。`--swarm` 有効時は Phase 2, 4, 8 で無視される |
| `--swarm` | Phase 1, 2, 4, 8 でエージェントチーム（TeamCreate）を使用する。メンバー間の直接通信・相互検証・議論ベース合意形成を有効化。デフォルト: false |
| `--linear` | Linear チケットへの進捗同期を有効化。`linear-sync` supplement skill を起動し、各フェーズ完了後に Linear へ同期する。 |

## The Pipeline

```
Feature Spec
    |
    v
Phase 1: Design ──────── superpowers:brainstorming [INTERACTIVE]
    | 設計書ドラフト完成 -> worktrunk で worktree 作成 -> 設計書コミット -> 自動遷移
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
    | 全タスク完了 -> 自動遷移（--doc 時は Phase 6 へ、--smoke 時 or UI検出時は Phase 7 へ、それ以外は Phase 8 へ）
    v
Phase 6: Doc Audit ───── /doc-audit [--doc 指定時のみ] [INTERACTIVE]
    | 全 finding 処理済み -> 自動遷移
    v
Phase 7: Smoke Test ──── /smoke-test [--smoke 指定時 or UI自動検出時] [AUTONOMOUS+GATE]
    | PASS -> 自動遷移
    v
Phase 8: Code Review ─── /code-review [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 9: Test Review ─── /test-review [--e2e 指定時のみ] [INTERACTIVE]
    | レビュー通過 -> handover -> 自動遷移
    v
Phase 10: Integrate ──── worktrunk:worktrunk [INTERACTIVE]
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
   - `verdict`: Audit Gate の verdict またはフェーズ固有の結果
   - `summary`: フェーズの成果要約
   - `test_results`: テスト実行結果（該当フェーズのみ）
   - `audit_observations`: phase-auditor の observations
   - `evidence_files`: アップロード対象ファイル
2. `claude/skills/linear-sync/SKILL.md` の `sync_phase` セクションの手順に従い実行
3. API 失敗時はワークフローをブロックせず続行

### Audit Team（`--swarm` 有効時）
`--swarm` 有効時、inspection 基準を含む Phase 1-9 の Audit Gate をエージェントチーム（3メンバー: automated-verifier, inspection-verifier, evidence-verifier）で実行する。メンバー間で findings を相互検証し、合意した verdict を返却する。Phase 10 は automated のみのため単一エージェント。詳細は `./references/audit-gate-protocol.md` セクション 10 を参照。

### Phase 10: Audit Gate Lite
Phase 10 は Agent を起動せず、`./done-criteria/phase-10-integrate.md` の基準をオーケストレーターが直接検証。

### Evidence Plan 生成（正規定義はここ。protocol には消費ロジックのみ）
Phase 1 Audit Gate 完了後に Evidence Plan を生成（phase-auditor が自動実行）。Phase 4 Audit Gate 完了後に再評価（設計書 hash 変更時のみ）。Evidence Plan は `docs/plans/` にコミットする。

### Evidence Collection（add-on）
Phase 5 以降の Executor 起動時、Evidence Plan から該当アクティビティの collection 要件を抽出しプロンプトに追加する。

### Phase 5 Re-gate + Re-review
Phase 8/9 でコード変更がある場合、Phase 8/9 の Audit Gate の前に:
1. git diff でコード変更を検知
2. Phase 5 Audit Gate を full mode で再実行
3. Phase 6 Re-gate (lightweight): `--doc` 有効時のみ。doc-audit.sh --range <fix-commit>..HEAD を実行。影響ありなら doc-check のみ実行（Layer 2 再実行なし）
4. Phase 7 Audit Gate を再実行（--smoke 有効時）
5. /code-review（または /test-review）を再実行
6. findings があれば修正 → Step 2 に戻る
7. findings がなければ Phase 8/9 Audit Gate へ
詳細は `./references/audit-gate-protocol.md` セクション 8 を参照。

### Linear Sync 初期化（`--linear` 有効時のみ）

1. `claude/skills/linear-sync/SKILL.md` を Read
2. `resolve_ticket` セクションの手順に従いチケットを特定
3. チケット確定後、`sync_workflow_start` セクションの手順に従い Document 作成・開始コメント投稿
4. `linear_ticket_id` と `linear_document_id` をワークフローコンテキストに保持

## Phase Details

### Phase 1: Design

- **INVOKE 1:** Read tool で `./references/brainstorming-supplement.md`（このスキルのディレクトリからの相対パス）を読み込む（brainstorming の事前制約・追加ステップを context に載せる）
- **INVOKE 2:** 直後に Skill tool で `superpowers:brainstorming` を invoke する
- **INVOKE 3:** 設計書ドラフト完成後、コミット前に `worktrunk:worktrunk` を invoke し、`wt switch -c <branch> [-b <base>]` で開発用 worktree とブランチを作成する。ベースブランチは設計フェーズのコンテキストから判断する（`/continue` 時は handover の記録から復元）
- **Autonomy:** INTERACTIVE
- **動作:** supplement が先に context に載った状態で brainstorming を実行する。supplement により TaskCreate 禁止・インタラクティブ制約が適用され、clarifying questions 後に **並列探索エージェント（code-explorer + code-architect + impact-analyzer）を起動してコードベースをサブ context で深く調査** し、その結果をもとに暗黙ルール抽出・テスト観点列挙が実行される。設計書ドラフト完成後、worktrunk（`wt switch -c`）で worktree を作成し、ベースラインテスト通過後に設計書を worktree 内にコミットする
- **`--swarm` 有効時（Exploration Team）:**
  並列探索をサブエージェントではなくエージェントチームで実行する。
  1. TeamCreate で Exploration Team を作成（チーム名: `exploration-{feature}`）
  2. メンバー: code-explorer, code-architect, impact-analyzer の3エージェント
  3. メンバー間通信を有効化: Explorer の発見 → Architect がパターン分析 → Impact が依存先を深掘り
  4. 共有タスク: Investigation Record の各セクション（prerequisites, impact_scope, reverse_dependencies, shared_state, implicit_contracts, side_effect_risks）をタスクとして割り当て
  5. チームが Investigation Record を共同作成し、メンバー間で相互検証した上で結果を返却
  6. チーム完了後、リーダー（オーケストレーター）がクリーンアップ
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
- **`--swarm` 有効時（Spec Review Team）:**
  `/spec-review` の代わりにエージェントチームでレビューを実行する。`--iterations` は無視される（チーム議論が投票を代替）。
  1. TeamCreate で Spec Review Team を作成（チーム名: `spec-review-{feature}`）
  2. メンバー: spec-review-requirements, spec-review-design-judgment, spec-review-feasibility, spec-review-consistency の4エージェント
  3. 各メンバーが自身の観点でレビュー後、他メンバーの findings を相互検証
  4. 矛盾する findings はメンバー間の議論で解決（例: feasibility が「不可能」、requirements が「必須」→ 代替案を議論）
  5. チームが合意した findings リストを返却
  6. チーム完了後クリーンアップ
- **自動遷移条件:** レビュー全観点パス（チームモード時: チーム合意で findings なし）
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
- **`--swarm` 有効時（Plan Review Team）:**
  `/implementation-review` の代わりにエージェントチームでレビューを実行する。`--iterations` は無視される。
  1. TeamCreate で Plan Review Team を作成（チーム名: `plan-review-{feature}`）
  2. メンバー: implementation-review-clarity, implementation-review-feasibility, implementation-review-consistency の3エージェント
  3. consistency エージェントには設計書パスを追加コンテキストとして渡し、設計→計画の整合性を検証
  4. 各メンバーが自身の観点でレビュー後、他メンバーの findings を相互検証
  5. チームが合意した findings リストを返却
  6. チーム完了後クリーンアップ
- **自動遷移条件:** レビュー全観点パス（チームモード時: チーム合意で findings なし）
- **成果物:** レビュー通過済み計画書
- **失敗時:** ユーザーヒアリング -> 修正 -> 再レビュー。3回不合格で PAUSE、計画の根本的見直しを提案
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 4 完了 → Audit Gate**: `./done-criteria/phase-4-plan-review.md` に基づき監査。activity_type: review-fix。Evidence Plan 再評価（設計書 hash 変更時）。

### Phase 5: Execute

- **INVOKE:** `superpowers:subagent-driven-development`
- **Autonomy:** AUTONOMOUS+GATE
- **実装エージェント:** `subagent-driven-development` が生成する各実装サブエージェントは `subagent_type: "feature-implementer"` で起動すること。`feature-implementer` は `skills: [superpowers:test-driven-development]` を frontmatter で宣言しており、TDD スキルがコンテキストに自動注入される。
- **動作:** レビュー通過済み計画書に基づき、オーケストレーターが計画を self-contained な実装 spec に再構成してから `feature-implementer` に渡し、TDD プロセスに従って実装を実行させる。広い調査結果をそのまま転送してはならない
- **自動遷移条件:** 全タスク完了
- **成果物:** コミット済みコード
- **失敗時:** 3回タスク失敗で PAUSE。設計ギャップをエスカレーション
- **GATE:** タスク失敗が累積した場合に PAUSE

**Phase 5 完了 → Audit Gate**: `./done-criteria/phase-5-execute.md` に基づき監査。activity_type: implementation。

### Phase 6: Doc Audit

- **INVOKE:** `/doc-audit`
- **Autonomy:** INTERACTIVE
- **有効条件:** `--doc` 指定時のみ。未指定時はスキップして Phase 7 へ（--smoke 有効時）または Phase 8 へ
- **動作:**
  1. ユーザーにスコープを確認: A（実装変更の影響のみ）or B（プロジェクト全体の棚卸し）
  2. Layer 0: 既存探索エージェント（code-explorer, code-architect, impact-analyzer）を doc-audit 用スコープで起動
  3. Layer 1: doc-audit.sh を実行（A: --range、B: --full）
  4. Layer 2: スクリプト結果 + 探索結果をエージェント群にフィード
  5. 統合レポート提示 → ユーザー finding 選択
  6. Layer 3: 修正実行（doc-check 連携含む）
- **`--swarm` 有効時（Doc Audit Team）:**
  Exploration Team + Audit Team の2チーム構成で実行。詳細は doc-audit スキルの agent-checklists.md を参照
- **自動遷移条件:** 全 finding 処理済み（修正 or スキップ）
- **成果物:** 更新済みドキュメント、修正済み depends-on、`doc-audit-report.json`
- **失敗時:** Audit Gate FAIL → Fix Dispatch → 再監査（max_retries: 2）

**Phase 6 完了 → Audit Gate**: `./done-criteria/phase-6-doc-audit.md` に基づき監査。activity_type: doc-maintenance。

### Phase 7: Smoke Test

- **INVOKE:** `/smoke-test`
- **Autonomy:** AUTONOMOUS+GATE
- **有効条件:** `--smoke` 指定時、または設計書に UI 関連キーワード（「画面」「UI」「ページ」「フォーム」「frontend」「component」「view」「page」「form」）が含まれる場合に自動有効化を提案（ユーザー確認あり）。未指定かつ UI 関連なしの場合はスキップして Phase 8 へ
- **引数伝播:** `args: "--diff-base <artifacts.branch_base> --design <artifacts.design_doc>"`
- **動作:** dev サーバーを起動し、Playwright でスモークテスト・VRT 差分チェック・E2E フレーキー検出を実行する
- **自動遷移条件:** smoke-test の終了ステータスが PASS
- **成果物:** `smoke-test-report.md`（一時ファイル）
- **失敗時:** FAIL → アプリケーションバグの修正を試行（最大2回）。修正不能なら PAUSE
- **GATE:** 終了ステータスが FAIL または PAUSE の場合に PAUSE

**Phase 7 完了 → Audit Gate**: `./done-criteria/phase-7-smoke-test.md` に基づき監査。activity_type: smoke-test。

### Phase 8: Code Review

- **INVOKE:** `/code-review`
- **Autonomy:** INTERACTIVE
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す。例: `args: "--codex --branch --iterations 3"`
- **動作:** 実装コードを7観点（simplify, quality, security, performance, test, ai-antipattern, impact）でレビューする
- **`--swarm` 有効時（Code Review Team）:**
  `/code-review` の代わりにエージェントチームでレビューを実行する。`--iterations` は無視される。
  1. TeamCreate で Code Review Team を作成（チーム名: `code-review-{feature}`）
  2. メンバー: code-review-quality, code-review-security, code-review-performance, code-review-test, code-review-ai-antipattern, code-review-impact の6エージェント
  3. simplify は Skill tool で Leader が別途実行（チーム外）
  4. code-review-impact には設計書の Impact Analysis セクションを追加コンテキストとして渡す
  5. メンバー間通信で相互検証: security vs performance のトレードオフ議論、quality vs ai-antipattern の相互チェック
  6. チームが合意した findings リスト + トレードオフ判断を返却
  7. チーム完了後クリーンアップ
- **Impact Findings 延期制限:**
  code-review-impact が severity: high 以上の finding を報告した場合、
  オーケストレーターはその finding を自動的に延期・却下してはならない。
  以下のいずれかをユーザーに明示的に確認する:
  1. **修正する**: finding に従い修正を実施
  2. **延期する**: ユーザーが影響を理解した上で明示的に承認（承認理由を記録）
  3. **却下する**: 誤検出の根拠をユーザーに提示し、ユーザーが却下を承認

  オーケストレーターの自己判断による延期は禁止。
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** レビュー修正済みコード
- **失敗時:** 修正後テスト失敗 -> 最大2回リトライ、それでも失敗なら PAUSE
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 8 完了 → Audit Gate**: `./done-criteria/phase-8-code-review.md` に基づき監査。activity_type: review-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 9: Test Review

- **INVOKE:** `/test-review --design <artifacts.design_doc>`
- **Autonomy:** INTERACTIVE
- **有効条件:** `--e2e` 指定時のみ。未指定時はスキップして Phase 10 へ
- **`--design` 伝播:** `artifacts.design_doc`（Phase 1 の設計書パス）を `--design` 引数として自動付与する
- **フラグ伝播:** `--codex` 指定時は `--codex` を、`--iterations N` は常に渡す（例: `args: "--design docs/plans/2026-03-11-xxx-design.md --codex --iterations 3"`）
- **動作:** テストコードを3観点（coverage, quality, design-alignment）でレビューする
- **自動遷移条件:** ユーザーが承認した修正完了
- **成果物:** テストレビュー済みコード
- **失敗時:** テスト追加後の既存テスト破損 -> PAUSE。影響範囲を報告
- **Handover:** 必須。レビュー完了後に `/handover` を実行する

**Phase 9 完了 → Audit Gate**: `./done-criteria/phase-9-test-review.md` に基づき監査。activity_type: test-fix。コード変更がある場合は Re-gate + Re-review を先行実行。

### Phase 10: Integrate

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

**Phase 10 完了 → Audit Gate Lite**: オーケストレーターが `./done-criteria/phase-10-integrate.md` を直接検証。

### Linear Sync 完了（`--linear` 有効時のみ）

全フェーズ完了後:
1. `claude/skills/linear-sync/SKILL.md` の `sync_complete` セクションの手順に従い実行
2. Document 最終更新、完了コメント投稿、ステータス更新

## Handover

### タイミング

レビューフェーズ（Phase 2, 4, 8, 9）完了後は **必ず** `/handover` を実行する。他フェーズは context 状況に応じて任意。

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
- フラグやオプションに関する補足（「--smoke は X の理由で有効化した」等）
- 特定のファイル・モジュールへの注意喚起

#### concern（品質懸念）
- 動作するが設計的に不安な箇所
- テストのフレーキーリスク
- パフォーマンス・セキュリティの潜在的問題

### パイプライン状態

`/handover` で保存する `project-state.json` に以下のパイプライン固有情報を含める:

```json
{
  "pipeline": "feature-dev",
  "current_phase": 3,
  "args": { "codex": true, "e2e": false, "smoke": false, "doc": false, "ui": false, "iterations": 3, "swarm": false, "linear": false },
  "linear_ticket_id": null,
  "linear_document_id": null,
  "artifacts": {
    "design_doc": "docs/plans/2026-03-06-xxx-design.md",
    "plan_doc": null,
    "worktree_path": null,
    "branch_name": null,
    "smoke_test_report": null,
    "doc_audit_report": null,
    "doc_audit_scope": null
  },
  "completed_phases": [1, 2],
  "review_history": {
    "spec_review": { "iterations": 2, "passed": true },
    "implementation_review": null
  },
  "phase_observations": [],
  "session_notes": []
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
| 1 | `docs/plans/*-design.md`（テスト観点セクション含む）、worktree パス、ブランチ名 | Phase 2, 3, 5, 9, 10 |
| 2 | レビュー通過済み設計書 | Phase 3 |
| 3 | `docs/plans/*-plan.md`, `docs/plans/*-test-cases.md` | Phase 4, 5 |
| 4 | レビュー通過済み計画書 | Phase 5 |
| 5 | コミット済みコード | Phase 6, 7, 8, 9 |
| 6 | 更新済みドキュメント、`doc-audit-report.json` | Phase 8 |
| 7 | `smoke-test-report.md`（一時ファイル） | Phase 8 |
| 8 | レビュー修正済みコード | Phase 9, 10 |
| 9 | テストレビュー済みコード | Phase 10 |

## Autonomy Summary

| Phase | Mode | 自動遷移 | GATE 条件 |
|-------|------|---------|-----------|
| 1: Design | INTERACTIVE | worktree 作成済み かつ 設計書コミット済み | テスト失敗 -> PAUSE |
| 2: Spec Review | INTERACTIVE | レビュー全観点パス | -- |
| 3: Plan | AUTONOMOUS | 計画書コミット済み | -- |
| 4: Plan Review | INTERACTIVE | レビュー全観点パス | -- |
| 5: Execute | AUTONOMOUS+GATE | 全タスク完了 | 3回失敗 -> PAUSE |
| 6: Doc Audit | INTERACTIVE | 全 finding 処理済み | Audit Gate FAIL -> PAUSE |
| 7: Smoke Test | AUTONOMOUS+GATE | PASS | FAIL/PAUSE -> PAUSE |
| 8: Code Review | INTERACTIVE | 修正完了 | -- |
| 9: Test Review | INTERACTIVE | 修正完了 | -- |
| 10: Integrate | INTERACTIVE | 選択完了 | -- |

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
| 6: Doc Audit | doc-audit.sh 実行失敗 | PAUSE。スクリプトエラーを報告 |
| 6: Doc Audit | finding 修正失敗 | Audit Gate FAIL → Fix Dispatch → 再監査（max_retries: 2） |
| 7: Smoke Test | サーバー起動不可 | PAUSE。ユーザーに起動コマンドを確認 |
| 7: Smoke Test | スモークテスト失敗（修正可能） | 自動修正 → 再実行（最大2回） |
| 7: Smoke Test | スモークテスト失敗（修正不能） | PAUSE。ユーザーに報告 |
| 8: Code Review | 修正後テスト失敗 | 最大2回リトライ、それでも失敗なら PAUSE |
| 9: Test Review | テスト追加後の既存テスト破損 | PAUSE。影響範囲を報告 |
| 10: Integrate | マージコンフリクト | コンフリクトを報告、手動解決を提案 |
| 全フェーズ | `--codex` 指定時に Codex 接続失敗 | 警告し codex なしで続行 |
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
| 1 | `superpowers:brainstorming`, `worktrunk:worktrunk` | superpower + plugin |
| 2 | `/spec-review` | custom skill |
| 3 | `superpowers:writing-plans` | superpower |
| 4 | `/implementation-review` | custom skill |
| 5 | `superpowers:subagent-driven-development` + `feature-implementer` agent (TDD skills 自動注入) | superpower + agent |
| 6 | `/doc-audit` | custom skill |
| 7 | `/smoke-test` | custom skill |
| 8 | `/code-review` | custom skill |
| 9 | `/test-review` | custom skill |
| 10 | `worktrunk:worktrunk`（+ `gh` for PR） | plugin |
| any | `/handover` | custom skill |
