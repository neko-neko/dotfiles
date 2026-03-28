---
name: audit-gate-protocol
description: >-
  feature-dev パイプラインの Audit Gate プロトコル。Phase 完了後の監査フロー、
  Fix Dispatch 戦略、Re-gate + Re-review ループ、PAUSE 復帰の全手順を定義する。
---

# Audit Gate Protocol

## 1. Audit Gate フロー

Phase N 完了後、以下の 6 ステップで Audit Gate を実行する。

```
### Phase N 完了後: Audit Gate

1. 成果物パスを `artifacts` に記録する
2. `done-criteria/phase-N-{name}.md` を Read で読み込む
3. Evidence Plan から該当アクティビティタイプの collection 要件が
   Executor に注入済みであることを確認
4. Agent ツールで `phase-auditor` を起動（Audit Context を注入）
5. 返却値の JSON 有効性と必須フィールドを検証
   - 不正な場合: 1回だけ再起動（fix loop とは別カウント）
   - 2回目も不正: PAUSE
6. verdict を判定:
   - PASS: quality_warnings をユーザーに提示し Phase N+1 へ進む
   - FAIL かつ escalation != null: 即 PAUSE（escalation 内容を提示）
   - FAIL かつ attempt < max_retries:
     a. FAIL 項目の fix_instruction を抽出
     b. Phase N の Fix Dispatch 戦略に従い修正を実行
     c. 累積診断を更新（Audit Agent が算出した diff_from_previous を append）
     d. attempt を +1 して手順 4 に戻る
   - FAIL かつ attempt >= max_retries:
     a. 累積診断レポートを生成
     b. PAUSE: ユーザーに提示し判断を委任
```

## 2. Audit Context テンプレート

Audit Agent（phase-auditor）への注入内容。

```markdown
## Audit Context

### Phase
phase: {N}
name: {phase_name}
attempt: {current_attempt}

### Done Criteria
{phase-N-done.md の全文}

### Evidence Plan
{evidence-plan.md の全文、または "未生成" }

### Artifacts to Verify
- primary: {成果物パス}
- dependencies: [{前フェーズ成果物}]

### Available Capabilities
- bash: true
- browser-automation: {playwright | chrome-in-chrome | none}
- database-access: {MCP server name | none}
- api-access: {true | false}

### Pipeline Configuration
active_phases: [1, 2, 3, 4, 5, 7, 9]
next_phase: {N+1 or skip先}

### Cumulative Diagnosis (attempt 2+ only)
{前回までの診断履歴 JSON}
```

## 3. Fix Dispatch 戦略

修正はオーケストレーターが **そのフェーズで使った既存のサブエージェント/スキル** に再委任する。

| Phase | Fix Executor | Fix Dispatch 戦略 |
|-------|-------------|-------------------|
| 1 Design | オーケストレーター自身 | 設計書を修正。不足情報があれば探索エージェント（code-explorer, impact-analyzer 等）を再起動 |
| 2 Spec Review | オーケストレーター自身 | 設計書を修正 |
| 3 Plan | オーケストレーター自身 | 計画書を修正 |
| 4 Plan Review | オーケストレーター自身 | 計画書を修正 |
| 5 Execute | 実装サブエージェント | fix_instructions をタスク単位に分解し、該当タスクの実装サブエージェントを再起動 |
| 6 Smoke Test | 実装サブエージェント | Phase 5 の実装サブエージェントを再起動 |
| 7 Code Review | 実装サブエージェント | Phase 5 の実装サブエージェントを再起動 |
| 8 Test Review | 実装サブエージェント | Phase 5 の実装サブエージェントを再起動 |
| 9 Integrate | オーケストレーター自身 | Audit Gate Lite のため Agent 不要 |

## 4. Fix Context テンプレート

サブエージェント再起動時は文脈が失われるため、以下を注入する。

```markdown
## Fix Context

### Original Task
{計画書から該当タスクの定義}

### Changes Made
{該当タスクが生成した git diff}

### Fix Instructions
{Audit Agent からの fix_instruction 全文: what/how/source/why/verify}

## Evidence Collection Requirements
{Evidence Plan から該当アクティビティタイプの collection 要件}

## Return Format
完了後、以下の JSON 形式で結果を返すこと:
{
  "fix_status": "completed | partial | blocked",
  "completed_fixes": ["基準ID", ...],
  "blocked_fixes": [{ "criteria_id": "...", "reason": "...", "suggestion": "..." }],
  "changes_summary": "変更内容のサマリ"
}
```

fix_status の挙動:
- `completed`: 通常通り Audit Agent で再監査
- `partial`: 完了分は再監査、blocked 分は累積診断に記録
- `blocked`: 即 PAUSE（修正不能）

## 5. INTERACTIVE フェーズでの Audit Gate 位置

Phase 2, 4, 7, 8 は既にレビューループを持つ。Audit Gate は **既存レビューループ完了後に 1 回だけ** 実行する。レビュー自体の再実行は行わない。

```
Phase 2: /spec-review 実行 → findings ループ（既存） → PASS
         → Audit Gate（D2-01〜D2-05 を検証）
         → PASS → Phase 3 へ
         → FAIL → 修正 → 再監査（レビュー自体は再実行しない）
```

## 6. PAUSE 復帰プロトコル

Audit Gate が PAUSE に到達した後、ユーザーが介入して再開する場合の手順。

1. ユーザーが修正を行った後「続行」を指示
2. attempt カウンタをリセット（1 に戻す）
3. 累積診断は保持（ユーザー修正前の履歴として有用）
4. cumulative_diagnosis に `"user_intervention": true` のマーカーを付与
5. Audit Agent を新たに起動（attempt=1、累積診断はコンテキストとして注入）

## 7. Handover State 拡張

パイプライン handover 時に保存する `audit_state` の JSON 構造。

```json
{
  "pipeline": "feature-dev",
  "current_phase": 5,
  "audit_state": {
    "current_attempt": 2,
    "max_retries": 3,
    "cumulative_diagnosis": [
      {
        "attempt": 1,
        "failed_criteria": ["D5-05", "D5-07"],
        "details": { "D5-05": "...", "D5-07": "..." },
        "diff_from_previous": null
      }
    ],
    "last_fix_dispatch": {
      "strategy": "subagent-relaunch",
      "target_tasks": ["task-3", "task-5"],
      "fix_summary": "..."
    }
  },
  "artifacts": {
    "design_doc": "docs/plans/...",
    "plan_doc": "docs/plans/...",
    "evidence_plan": "docs/plans/...",
    "worktree_path": "...",
    "branch_name": "..."
  },
  "args": { "codex": false, "e2e": false, "smoke": true, "iterations": 3 }
}
```

## 8. Phase 5 Re-gate + Re-review ループ

Phase 5 以降でコード変更が発生した場合、GitHub PR の「push fix -> CI -> re-review」サイクルを再現する。CI（Phase 5/6 Re-gate）だけでなく、レビュー自体も再実行する。

### 8.1 GitHub PR フローとの対比

```
GitHub PR:
  push → CI → review → changes requested
    → push fix → CI → re-review → changes requested
    → push fix → CI → re-review → approved → merge

feature-dev:
  Phase 5 → Audit → [Phase 6] → Phase 7(review) → findings → fix
    → Phase 5 Re-gate → [Phase 6 Re-gate] → /code-review(re-review) → findings → fix
    → Phase 5 Re-gate → [Phase 6 Re-gate] → /code-review(re-review) → no findings
    → Phase 7 Audit Gate → Phase 9(merge)
```

| GitHub PR | feature-dev |
|-----------|-------------|
| push | コード変更（fix 適用） |
| CI | Phase 5 Re-gate + Phase 6 Re-gate |
| review / re-review | /code-review（または /test-review） |
| approve | Phase 7/8 Audit Gate |
| merge | Phase 9 |

### 8.2 フロー詳細

```
Phase 7: /code-review → findings → 修正適用
  |
  +-- git diff でコード変更を検知
  |
  +-- コード変更あり → Re-review ループ開始
  |    |
  |    +-- Step 1: Phase 5 Audit Gate 再実行（full mode）
  |    |    +-- PASS -> Step 2
  |    |    +-- FAIL -> Fix -> Phase 5 Re-gate 再実行 -> (max_retries -> PAUSE)
  |    |
  |    +-- Step 2: Phase 6 Audit Gate 再実行（--smoke 有効時）
  |    |    +-- PASS -> Step 3
  |    |    +-- FAIL -> Fix -> Step 1 に戻る（コード変更が発生するため）
  |    |
  |    +-- Step 3: /code-review 再実行（修正コードのレビュー）
  |    |    +-- findings なし -> Step 4
  |    |    +-- findings あり -> ユーザー承認 -> 修正適用
  |    |         -> Step 1 に戻る（コード変更が発生するため）
  |    |
  |    +-- Step 4: Phase 7 Audit Gate（D7-01...D7-03）
  |
  +-- コード変更なし
       +-- Phase 7 Audit Gate のみ
```

Phase 8 も同様（/code-review の代わりに /test-review）。

### 8.3 ループ終了条件

Re-review ループは以下のいずれかで終了する:

1. **正常終了**: Phase 5 Re-gate PASS -> Phase 6 Re-gate PASS -> re-review で findings なし -> Phase 7 Audit Gate へ
2. **PAUSE（Re-gate 失敗）**: Phase 5 or Phase 6 の Re-gate が max_retries に到達
3. **PAUSE（Re-gate escalation）**: Phase 5 Re-gate で escalation が発生
4. **PAUSE（re-review 繰り返し）**: re-review が 3 回連続で findings を出す場合、PAUSE して根本的な設計見直しを促す

### 8.4 Re-gate の attempt カウンタ

- Re-gate は呼び出し元（Phase 7/8）の attempt とは独立したカウンタを持つ
- 各 Re-review ループの開始時に Re-gate の attempt はリセットされる
- max_retries は Phase 5/6 の done-criteria ファイルに定義された値を使用

### 8.5 Evidence 再収集

Re-gate 実行時、Evidence Plan の collection 要件も再適用される:

- Phase 5 Re-gate: implementation アクティビティのエビデンスを再収集
- Phase 6 Re-gate: smoke-test アクティビティのエビデンスを再収集
- エビデンスファイルは上書き（最新の状態が常に反映される）

### 8.6 Re-gate + Re-review が解決する問題

| Phase | リスク | 検出手段 |
|-------|--------|---------|
| Phase 7 | 修正でビルドが壊れる | Phase 5 Re-gate D5-02 |
| Phase 7 | 修正で既存テストが FAIL | Phase 5 Re-gate D5-04 |
| Phase 7 | 修正でコンポーネント境界を破壊 | Phase 5 Re-gate D5-06 |
| Phase 7 | 修正で UI が壊れる | Phase 6 Re-gate |
| Phase 7 | 修正が新たなセキュリティ問題を導入 | re-review（security 観点） |
| Phase 7 | 修正が新たなパフォーマンス問題を導入 | re-review（performance 観点） |
| Phase 8 | テスト追加で既存テストとの競合 | Phase 5 Re-gate D5-04 |
| Phase 8 | テスト修正がトレーサビリティを破壊 | Phase 5 Re-gate D5-07 |

## 9. Audit Gate Lite（Phase 9）

Phase 9 は Audit Agent を起動しない。オーケストレーターが直接検証する。

| ID | 基準 | verify_type |
|----|------|-------------|
| D9-01 | ユーザーが統合方法を選択済み | automated |
| D9-02 | 選択されたアクションが完了（merge commit / PR URL / branch 存在） | automated |
| D9-03 | マージコンフリクトがない + 未コミット変更がない | automated |

全基準が automated であり Audit Agent の judgment が不要なため、Agent を起動せずオーケストレーターが git コマンド等で直接検証する。
