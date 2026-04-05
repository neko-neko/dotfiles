---
name: audit-gate-protocol
description: >-
  workflow-engine 共通の Audit Gate プロトコル。Phase 完了後の監査フロー、
  Fix Dispatch 戦略、Re-gate + Re-review ループ、PAUSE 復帰の全手順を定義する。
  憲法的ルール（スキップ禁止）を含む。
---

## 憲法的ルール（Constitutional Rules）

以下のルールはパイプライン実行において例外なく適用される。

- パイプラインのフェーズ遷移時、done-criteria に定義された監査ゲートは例外なく実行すること
- audit: required → phase-auditor エージェントを起動。省略・スキップ禁止
- audit: lite → エンジン自身が基準を直接検証。省略・スキップ禁止
- 監査未実行のフェーズ遷移は無効とみなす
- コンテキスト逼迫・時間的制約を理由にした監査スキップは認めない。逼迫時は handover を実行せよ

# Audit Gate Protocol

本ドキュメントはフェーズをセマンティック ID `{phase_id}` で参照する。
番号とのマッピングは各パイプラインの `pipeline.yml` を参照。

<HARD-GATE>
このプロトコルは任意ではない。各フェーズ完了後の Audit Gate 実行は必須である。
done-criteria の `audit: required` フェーズで phase-auditor を起動せずに遷移した場合、
パイプラインの品質保証は無効となる。
</HARD-GATE>

## 1. Audit Gate フロー

Phase N 完了後、以下の 6 ステップで Audit Gate を実行する。

```
### Phase N 完了後: Audit Gate

1. 成果物パスを `artifacts` に記録する
2. `done-criteria/phase-N-{name}.md` を Read で読み込む
3. Evidence Plan から該当アクティビティタイプの collection 要件が
   Executor に注入済みであることを確認
4. Audit Agent を起動:
   - `--swarm` 無効時: 単一の `phase-auditor` を Agent ツールで起動（Audit Context を注入）
   - `--swarm` 有効時 かつ inspection 基準あり: Audit Team を起動（後述セクション 10 参照）
   - `--swarm` 有効時 かつ inspection 基準なし（{integrate} 等）: 単一の `phase-auditor`
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
- api-access: {true | false}

### Pipeline Configuration
active_phases: [1, 2, 3, 4, 5, 7, 9]
next_phase: {N+1 or skip先}

### Cumulative Diagnosis (attempt 2+ only)
{前回までの診断履歴 JSON}
```

## 2.1 Audit-Only Phase と audit_target Projection

`plan-review` / `fix-plan-review` のような審査専用フェーズは pipeline.yml の
artifacts に対応する定義を持たない（空の report artifact を生成しない）。
これらのフェーズは done-criteria の `audit_target:` メタデータを通じて、
上流 artifact に対する追加 validation を宣言する。

### audit-only phase の定義

**audit-only phase** とは、`pipeline.yml` の `artifacts` セクション中に `produced_by` がそのフェーズ ID と一致する artifact を一つも持たないフェーズを指す。この定義は機械的に検証可能で、`jig lint` 等の静的検査が LR-C2 （本文書で言及する将来の lint rule）で利用する想定である。

現時点で Cluster 1 以降の dotfiles パイプラインに存在する audit-only phase は `plan-review` と `fix-plan-review` の 2 件。将来 audit-only phase を追加する際は、本セクションの規定（done-criteria で `audit_target:` を宣言すること、空 report artifact を `pipeline.yml` に置かないこと）に従うこと。

### 判定と合流ロジック

Phase N の done-criteria に以下の記述があるとき:

```
### <artifact_name>

audit_target: <upstream_artifact>
additional:
  - question: "..."
    severity: blocker
```

- `<artifact_name>` は section 識別子として保持（人間可読用）
- `<upstream_artifact>` が Phase N の produced artifact に含まれる場合 → エラー
  （audit_target は非-produced 上流 artifact にのみ適用される）
- `<upstream_artifact>` が pipeline.yml の artifacts に存在しない場合 → エラー
- 上記条件を満たす場合、`additional` の各 validation 項目は
  `<upstream_artifact>.contract.validation` に Phase N のコンテキストで合流する

**サブセクション名 = `audit_target` 値の場合**: `<artifact_name>`（サブセクション識別子）と `<upstream_artifact>`（`audit_target` 値）が同一文字列でも構わない。たとえば `plan-review` の done-criteria で `### implementation_plan` + `audit_target: implementation_plan` と書いても (f2) 経路で正しく処理される。これは Phase N が `implementation_plan` を produce していない（audit-only phase のため）ので (f1) が vacuously false となり (f2) が発火するためである。

### 合流した validation の評価タイミング

合流した validation 項目は Phase N の Audit Gate で評価される（上流 artifact を
produce した元フェーズの Audit Gate では評価されない）。これにより
「レビューフェーズは上流 artifact の contract を強化する」という意味論が保たれる。

### silent ignore の禁止

done-criteria の `artifact_validation` サブセクションが (f1)（self produce マッチ）
にも (f2)（audit_target マッチ）にも該当しない場合、engine は warning を発して
スキップする。将来 `jig lint` が同パターンを静的検出する予定（jig Phase 1 の
lint rule LR-C2 参照）。

## 3. Fix Dispatch 戦略

修正はオーケストレーターが **そのフェーズで使った既存のサブエージェント/スキル** に再委任する。

| Phase ID | Fix Executor | Fix Dispatch 戦略 |
|----------|-------------|-------------------|
| {design} | オーケストレーター自身 | 設計書を修正。不足情報があれば探索エージェント（code-explorer, impact-analyzer 等）を再起動 |
| {spec-review} | オーケストレーター自身 | 設計書を修正 |
| {plan} | オーケストレーター自身 | 計画書を修正 |
| {plan-review} | オーケストレーター自身 | 計画書を修正 |
| {rca} | オーケストレーター自身 | RCA レポートを修正。不足情報があれば探索エージェントを再起動 |
| {fix-plan} | オーケストレーター自身 | 修正計画を修正 |
| {fix-plan-review} | オーケストレーター自身 | 修正計画を修正 |
| {execute} | `feature-implementer` | fix_instructions をタスク単位に分解し、`subagent_type: "feature-implementer"` で起動（TDD skills 自動注入） |
| {accept-test} | `feature-implementer` | {execute} の `feature-implementer` を再起動 |
| {doc-audit} | オーケストレーター / doc-check / `feature-implementer` | 修正種別で振り分け: depends-on→Edit、内容更新→doc-check、新規作成→feature-implementer |
| {review} | `feature-implementer` | {execute} の `feature-implementer` を再起動 |
| {integrate} | オーケストレーター自身 | Audit Gate Lite のため Agent 不要 |

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

{spec-review}, {plan-review}, {fix-plan-review}, {review} は既にレビューループを持つ。Audit Gate は **既存レビューループ完了後に 1 回だけ** 実行する。レビュー自体の再実行は行わない。

```
{spec-review}: /spec-review 実行 → findings ループ（既存） → PASS
               → Audit Gate を検証
               → PASS → {plan} へ
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
        "failed_criteria": ["EXE-05", "EXE-07"],
        "details": { "EXE-05": "...", "EXE-07": "..." },
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
  "args": { "codex": false, "e2e": false, "accept": true, "doc": false, "ui": false, "iterations": 3, "swarm": false }
}
```

## 8. {execute} Re-gate + Re-review ループ

{execute} 以降でコード変更が発生した場合、GitHub PR の「push fix -> CI -> re-review」サイクルを再現する。CI（{execute}/{accept-test}/{doc-audit} Re-gate）だけでなく、レビュー自体も再実行する。

### 8.1 GitHub PR フローとの対比

```
GitHub PR:
  push → CI → review → changes requested
    → push fix → CI → re-review → changes requested
    → push fix → CI → re-review → approved → merge

pipeline:
  {execute} → Audit → [{accept-test}] → [{doc-audit}] → {review} → findings → fix
    → {execute} Re-gate → [{accept-test} Re-gate] → [{doc-audit} Re-gate] → /code-review(re-review) → findings → fix
    → {execute} Re-gate → [{accept-test} Re-gate] → [{doc-audit} Re-gate] → /code-review(re-review) → no findings
    → {review} Audit Gate → {integrate}(merge)
```

| GitHub PR | pipeline |
|-----------|----------|
| push | コード変更（fix 適用） |
| CI | {execute} Re-gate + {accept-test} Re-gate + {doc-audit} Re-gate |
| review / re-review | /code-review（または /test-review） |
| approve | {review} Audit Gate |
| merge | {integrate} |

### 8.2 フロー詳細

```
{review}: /code-review → findings → 修正適用
  |
  +-- git diff でコード変更を検知
  |
  +-- コード変更あり → Re-review ループ開始
  |    |
  |    +-- Step 1: {execute} Audit Gate 再実行（full mode）
  |    |    +-- PASS -> Step 2
  |    |    +-- FAIL -> Fix -> {execute} Re-gate 再実行 -> (max_retries -> PAUSE)
  |    |
  |    +-- Step 2: {doc-audit} Re-gate（--doc 有効時のみ、lightweight）
  |    |    +-- doc-audit.sh --range <fix-commit>..HEAD 実行
  |    |    +-- 影響なし -> Step 3
  |    |    +-- 影響あり -> doc-check のみ実行（Layer 2 再実行なし）-> Step 3
  |    |
  |    +-- Step 3: {accept-test} Audit Gate 再実行（--accept 有効時）
  |    |    +-- PASS -> Step 4
  |    |    +-- FAIL -> Fix -> Step 1 に戻る（コード変更が発生するため）
  |    |
  |    +-- Step 4: /code-review 再実行（修正コードのレビュー）
  |    |    +-- findings なし -> Step 5
  |    |    +-- findings あり -> ユーザー承認 -> 修正適用
  |    |         -> Step 1 に戻る（コード変更が発生するため）
  |    |
  |    +-- Step 5: {review} Audit Gate
  |
  +-- コード変更なし
       +-- {review} Audit Gate のみ
```

### 8.3 ループ終了条件

Re-review ループは以下のいずれかで終了する:

1. **正常終了**: {execute} Re-gate PASS -> {accept-test} Re-gate PASS -> {doc-audit} Re-gate PASS -> re-review で findings なし -> {review} Audit Gate へ
2. **PAUSE（Re-gate 失敗）**: {execute} or {accept-test} の Re-gate が max_retries に到達
3. **PAUSE（Re-gate escalation）**: {execute} Re-gate で escalation が発生
4. **PAUSE（re-review 繰り返し）**: re-review が 3 回連続で findings を出す場合、PAUSE して根本的な設計見直しを促す

### 8.4 Re-gate の attempt カウンタ

- Re-gate は呼び出し元（{review}）の attempt とは独立したカウンタを持つ
- 各 Re-review ループの開始時に Re-gate の attempt はリセットされる
- max_retries は {execute}/{accept-test} の done-criteria ファイルに定義された値を使用

### 8.5 Evidence 再収集

Re-gate 実行時、Evidence Plan の collection 要件も再適用される:

- {execute} Re-gate: implementation アクティビティのエビデンスを再収集
- {doc-audit} Re-gate: doc-maintenance アクティビティのエビデンスを再収集（lightweight: doc-audit.sh + doc-check のみ）
- {accept-test} Re-gate: accept-test アクティビティのエビデンスを再収集
- エビデンスファイルは上書き（最新の状態が常に反映される）

### 8.6 Re-gate + Re-review が解決する問題

| Phase ID | リスク | 検出手段 |
|----------|--------|---------|
| {review} | 修正でビルドが壊れる | {execute} Re-gate |
| {review} | 修正で既存テストが FAIL | {execute} Re-gate |
| {review} | 修正でコンポーネント境界を破壊 | {execute} Re-gate |
| {review} | 修正でドキュメントが乖離する | {doc-audit} Re-gate |
| {review} | 修正で UI が壊れる | {accept-test} Re-gate |
| {review} | 修正が新たなセキュリティ問題を導入 | re-review（security 観点） |
| {review} | 修正が新たなパフォーマンス問題を導入 | re-review（performance 観点） |

## 9. Audit Gate Lite（{integrate}）

{integrate} は Audit Agent を起動しない。オーケストレーターが直接検証する。

| 基準 | verify_type |
|------|-------------|
| ユーザーが統合方法を選択済み | automated |
| 選択されたアクションが完了（merge commit / PR URL / branch 存在） | automated |
| マージコンフリクトがない + 未コミット変更がない | automated |

全基準が automated であり Audit Agent の judgment が不要なため、Agent を起動せずオーケストレーターが git コマンド等で直接検証する。

## 10. Audit Team（`--swarm` 有効時）

`--swarm` フラグ有効時、inspection 基準を含むフェーズの Audit Gate をエージェントチームで実行する。automated 基準のみのフェーズ（{integrate}）は単一エージェントのまま。

### 10.1 チーム構成

```
Team: audit-{feature}-phase-{N}
Leader: オーケストレーター

Member A（automated-verifier）:
  - automated 基準の全評価
  - Layer 1 evidence（claimed）の存在確認
  - ビルド/lint/テスト等の実行結果の検証

Member B（inspection-verifier）:
  - inspection 基準の全評価
  - トレーサビリティ、網羅性、整合性の判定
  - pass_condition に対する判断

Member C（evidence-verifier）:
  - Layer 2 evidence（verified）の独立再検証
  - available capabilities に応じてテスト再実行、DB 直接確認、URL アクセス等
  - claimed evidence と verified 結果の照合
```

### 10.2 チーム動作フロー

```
1. TeamCreate で Audit Team を作成
2. 3メンバーに Audit Context + Done Criteria + Evidence Plan を配布
3. 各メンバーが担当範囲の基準を独立評価
4. メンバー間で findings を共有・相互検証:
   - A が automated で PASS した項目を B が inspection 観点で再確認
   - C の Layer 2 検証結果が A の Layer 1 結果と矛盾する場合に議論
   - B の inspection 判定に C が evidence で裏付けまたは反証
5. チームが合意した verdict + criteria_results を統合出力
6. チーム完了後クリーンアップ
```

### 10.3 verdict の合意ルール

- automated 基準: Member A の結果が最終（機械的検証に議論は不要）
- inspection 基準: Member B の判定に Member A/C が異議を唱えた場合、議論で解決
- evidence 検証: Layer 2 結果が Layer 1 と矛盾する場合、Layer 2 を優先（独立検証の方が信頼性が高い）
- 最終 verdict: 全 blocker 基準が PASS で合意 → PASS、いずれかで FAIL 合意 → FAIL

### 10.4 出力プロトコル

チームの統合出力は単一 phase-auditor と同一の JSON 形式。オーケストレーターから見た Audit Gate フロー（ステップ 5 以降）は変わらない。

```json
{
  "phase": N,
  "attempt": N,
  "verdict": "PASS | FAIL",
  "criteria_results": [...],
  "summary": {
    "total": N, "passed": N, "failed": N,
    "blocking_issues": [...],
    "quality_warnings": [...],
    "verification_coverage": {
      "fully_verified": N,
      "claimed_only": N,
      "unverifiable": N
    }
  },
  "escalation": null | {...},
  "diff_from_previous": null | {...}
}
```

### 10.5 適用条件

inspection 基準を持つフェーズで Audit Team が適用される。具体的な基準 ID は各フェーズの done-criteria ファイルを参照。

| Phase ID | Audit Team 適用 | 備考 |
|----------|----------------|------|
| {design} / {rca} | Yes | |
| {spec-review} / {fix-plan} | Yes | |
| {plan} / {fix-plan-review} | Yes | |
| {plan-review} | Yes | |
| {execute} | Yes | 最も恩恵大（inspection 基準が多い） |
| {accept-test} | Yes | |
| {doc-audit} | Yes | inspection 基準が多い |
| {review} | Yes | |
| {integrate} | No | 単一エージェント（Audit Gate Lite） |

**{doc-audit} 基準割り当て（例）:**
- automated-verifier: パス不存在、未宣言、デッドリンク、frontmatter、doc-check
- inspection-verifier: 孤立ドキュメント、陳腐化、一貫性、欠落
- evidence-verifier: ビジネスルール、設計判断、README/CHANGELOG、CLAUDE.md

### 10.6 単一エージェントとの使い分け

| | 単一 phase-auditor（デフォルト） | Audit Team（--swarm） |
|---|---|---|
| inspection 判定 | 1エージェントの判断 | 3エージェントの相互検証 |
| evidence 検証 | 1エージェントが L1+L2 両方 | 専任メンバーが L2 に集中 |
| コスト | 低 | 高（3インスタンス） |
| 偽陽性/偽陰性 | 単一判断のブレリスク | 相互検証で低減 |
| 推奨場面 | 通常開発 | 高品質要求・クリティカルな機能開発 |
