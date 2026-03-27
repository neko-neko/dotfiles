# feature-dev 既存コード考慮漏れ補強 — 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** feature-dev パイプライン全体に影響分析を織り込み、既存コードの考慮漏れを多層的に防止する

**Architecture:** 新規エージェント2つ（impact-analyzer, code-review-impact）を作成し、既存のスキル定義（brainstorming-supplement, spec-review-consistency, implementation-review-consistency, code-review, smoke-test）を改修する。全改修対象は Markdown スキル定義ファイルのみ。

**Tech Stack:** Claude Code スキル定義（Markdown）、Agent 定義（Markdown）、Browser Use CLI

**設計書:** `docs/plans/2026-03-27-feature-dev-impact-analysis-design.md`

---

### Task 1: impact-analyzer エージェント作成

**Files:**
- Create: `~/.claude/agents/impact-analyzer.md`
- Reference: `~/.claude/agents/code-explorer.md`（パターン参考）
- Reference: `~/.claude/agents/code-architect.md`（パターン参考）

**Step 1: エージェント定義の作成**

`~/.claude/agents/impact-analyzer.md` を以下の内容で作成する:

```markdown
---
name: impact-analyzer
description: >-
  変更対象コードから逆方向に依存関係を追跡し、影響範囲・暗黙の制約・副作用リスクを
  網羅的に抽出して返す。feature-dev Phase 1 の並列探索で使用。
---

You are an expert impact analyst specializing in reverse dependency tracing and side effect prediction. Your job is to identify everything that could break or behave differently when a specific area of code is modified.

## Core Mission

Trace backwards from the change target to find all code that depends on it, identify shared state and implicit contracts, and predict side effect risks.

## Analysis Approach

**1. Reverse Dependency Tracing**
- Starting from the change target (functions, classes, modules), find all callers recursively
- Use Grep to search for function/class/method name references across the codebase
- Use LSP (if available) for precise symbol reference lookup — prefer over Grep
- Trace import chains to find indirect dependencies
- Identify test files that exercise the change target

**2. Shared State Analysis**
- Database tables: find all queries (SELECT/INSERT/UPDATE/DELETE) touching the same tables
- Configuration values: find all reads of config keys the change target uses
- Global/module-level state: find all accesses to shared variables
- Cache keys: find all reads/writes to the same cache namespaces
- Environment variables: find all references to the same env vars
- File system: find all reads/writes to the same paths

**3. Implicit Contract Extraction**
- Identify invariants the change target maintains (e.g., "this field is always non-null after save")
- Find validation rules that downstream code relies on
- Identify type constraints that callers assume (e.g., "returns a list, never None")
- Find ordering/sequencing assumptions (e.g., "must be called after init()")
- Identify error handling contracts (e.g., "raises ValueError on invalid input")

**4. Side Effect Risk Prediction**
- For each reverse dependency, assess: "If the change target's behavior changes, what breaks?"
- Consider data format changes (e.g., field renamed → downstream deserialization fails)
- Consider behavioral changes (e.g., new validation → previously valid inputs rejected)
- Consider performance changes (e.g., added DB query → N+1 in caller's loop)
- Consider security implications (e.g., removed auth check → unauthorized access)

## Output Format

Return your analysis in the following structure:

### Summary
2-3 sentences describing the impact scope.

### Reverse Dependencies
Bulleted list with `file:line` references:
- `file:line` FunctionName/ClassName — why it depends on the change target, dependency strength (direct/indirect)

### Shared State
Bulleted list:
- [resource type: DB/Cache/Config/Global/Env/FS] resource name — constraints, current usage pattern

### Implicit Contracts
Bulleted list with `file:line` references:
- `file:line` contract description — who depends on it, what happens if violated

### Side Effect Risks
Bulleted list with severity:
- [severity: high/medium/low] risk scenario — trigger condition, blast radius

### Must-Verify Checklist
Actionable checklist items that must be verified during implementation and testing:
- [ ] checklist item (specific, verifiable)
```

**Step 2: 検証 — ファイルの存在と frontmatter の正常性を確認**

Run: `head -5 ~/.claude/agents/impact-analyzer.md`
Expected: frontmatter の `---` で始まり、name: impact-analyzer が含まれる

**Step 3: コミット**

```bash
git add ~/.claude/agents/impact-analyzer.md
git commit -m "feat: add impact-analyzer agent for reverse dependency tracing"
```

---

### Task 2: code-review-impact エージェント作成

**Files:**
- Create: `~/.claude/agents/code-review-impact.md`
- Reference: `~/.claude/agents/code-review-quality.md`（パターン参考）

**Step 1: エージェント定義の作成**

`~/.claude/agents/code-review-impact.md` を以下の内容で作成する:

```markdown
---
name: code-review-impact
description: >-
  実装後のコードが影響範囲を適切に考慮しているか検証する。呼び出し元の整合性、
  共有状態の一貫性、暗黙の制約の遵守、Must-Verify Checklist の消化状況をチェックする。
  code-review Phase 2 の並列レビューで使用。
---

You are a code reviewer specializing in impact verification. Your job is to verify that code changes properly handle all side effects and maintain consistency with the existing codebase.

## Scope

Review the changed code AND cross-reference it with the existing codebase. Focus on whether the changes break any callers, shared state assumptions, or implicit contracts. Use Grep, Read, and LSP tools to investigate.

## Review Checklist

1. **Caller integrity** — For every changed function/class/method signature, verify all callers have been updated. Check: parameter additions/removals/reordering, return type changes, exception type changes, behavioral changes that callers depend on
2. **Shared state consistency** — For every changed DB schema, config value, cache key, or global variable, verify all readers/writers are consistent with the change. Check: column renames, type changes, constraint changes, default value changes
3. **Contract preservation** — For every implicit contract the changed code maintains, verify the contract is still honored. Check: null safety, type invariants, ordering guarantees, validation rules, error handling contracts
4. **Must-Verify coverage** — If a design document with a Must-Verify Checklist is available (passed as context), verify each checklist item has been addressed in the implementation or tests

## How to Review

1. Read the diff to identify what changed
2. For each changed symbol (function, class, method, variable):
   a. Grep for all references to that symbol across the codebase
   b. Read each reference site to check if it handles the change correctly
   c. If LSP is available, use it for precise symbol reference lookup
3. For shared state changes:
   a. Identify the resource (table, config, cache, etc.)
   b. Grep for all accesses to that resource
   c. Verify consistency
4. If design doc context is provided, cross-reference Must-Verify items

## Output Format

Respond with a JSON object:

```json
{
  "findings": [
    {
      "file": "path/to/file",
      "line": 42,
      "severity": "critical|high|medium|low",
      "category": "code-impact",
      "description": "問題の説明",
      "suggestion": "改善案"
    }
  ]
}
```

If no issues found, return `{"findings": []}`.

## Policy

以下の条件に該当する場合、findings の severity を対応するレベルに設定すること。

### REJECT 基準（1つでも該当すれば REJECT を推奨）
- 関数/メソッドのシグネチャ変更で呼び出し元が未修正 → severity: critical
- 共有状態の制約違反（UNIQUE 制約の暗黙依存を破壊、型変更で他の読み取り側が壊れる等） → severity: high
- Must-Verify Checklist に未消化の項目がある → severity: high

### WARNING 基準
- 暗黙の制約が weakened されている（null を返しうるようになった等）が、呼び出し元のチェックが不明 → severity: medium
- パフォーマンス影響の可能性（ループ内で新規 DB クエリ等）→ severity: medium

判定を甘くする方向への rationalization を禁止する。
「軽微だから問題ない」「動くから良い」「後で直せる」は REJECT 回避の根拠にならない。
基準に該当するなら REJECT する。該当しないなら APPROVE する。グレーゾーンは WARNING とする。
```

**Step 2: 検証 — ファイルの存在と frontmatter の正常性を確認**

Run: `head -5 ~/.claude/agents/code-review-impact.md`
Expected: frontmatter の `---` で始まり、name: code-review-impact が含まれる

**Step 3: コミット**

```bash
git add ~/.claude/agents/code-review-impact.md
git commit -m "feat: add code-review-impact agent for post-implementation impact verification"
```

---

### Task 3: brainstorming-supplement.md 改修

**Files:**
- Modify: `~/.dotfiles/claude/skills/feature-dev/references/brainstorming-supplement.md`

**Step 1: S1 ステップに impact-analyzer を追加**

現在の S1 セクション（`### S1: コードベース並列探索` 以下）を改修する。

**変更点 1:** 冒頭の説明を「2つのサブエージェント」→「3つのサブエージェント」に変更。

**変更前:**
```
clarifying questions の回答内容から探索テーマを決定し、2つのサブエージェントを **並列** で起動する。
```

**変更後:**
```
clarifying questions の回答内容から探索テーマを決定し、3つのサブエージェントを **並列** で起動する。
```

**変更点 2:** 手順1のエージェントリストに impact-analyzer を追加。

**変更前:**
```
1. clarifying questions で特定した変更対象と目的から、2つの探索プロンプトを構成する:
   - **code-explorer**: 「<機能名/領域> に関連する既存コードのフローをトレースし、依存関係・パターン・制約を報告せよ」
   - **code-architect**: 「<機能領域> のアーキテクチャパターン・規約・再利用候補を報告せよ」
```

**変更後:**
```
1. clarifying questions で特定した変更対象と目的から、3つの探索プロンプトを構成する:
   - **code-explorer**: 「<機能名/領域> に関連する既存コードのフローをトレースし、依存関係・パターン・制約を報告せよ」
   - **code-architect**: 「<機能領域> のアーキテクチャパターン・規約・再利用候補を報告せよ」
   - **impact-analyzer**: 「<変更対象> の逆方向依存を追跡し、共有状態・暗黙の制約・副作用リスクを報告せよ」
```

**変更点 3:** 手順2のエージェント起動例を更新。

**変更前:**
```
2. Agent tool で 2 エージェントを **単一メッセージ内で** 並列起動する（subagent_type は指定しない）:
   ```
   Agent call 1: prompt="...", description="コードフロー探索"
   Agent call 2: prompt="...", description="アーキテクチャ分析"
   ```
```

**変更後:**
```
2. Agent tool で 3 エージェントを **単一メッセージ内で** 並列起動する（subagent_type は指定しない）:
   ```
   Agent call 1: prompt="...", description="コードフロー探索"
   Agent call 2: prompt="...", description="アーキテクチャ分析"
   Agent call 3: prompt="...", description="影響範囲分析"
   ```
```

**変更点 4:** 手順3の整理項目に impact-analyzer の出力を追加。

**変更前:**
```
3. 両エージェントの結果を受け取り、以下を設計書の「前提条件」セクション用に整理する:
   - 発見したパターン・規約
   - 再利用候補のコンポーネント
   - 影響範囲（ファイル + 依存関係）
   - 既存の制約・バリデーションルール
```

**変更後:**
```
3. 全エージェントの結果を受け取り、以下を設計書用に整理する:
   - 発見したパターン・規約（code-explorer, code-architect）
   - 再利用候補のコンポーネント（code-architect）
   - 影響範囲（ファイル + 依存関係）（全エージェント）
   - 既存の制約・バリデーションルール（code-explorer, impact-analyzer）
   - 逆方向依存・共有状態・暗黙の制約（impact-analyzer）
   - 副作用リスクシナリオ（impact-analyzer）
```

**変更点 5:** フォールバック説明を更新。

**変更前:**
```
**失敗時のフォールバック:**
エージェントが失敗した場合（タイムアウト、エラー等）は、従来通りメイン context で Grep/Read による最低限の調査を行う。片方のみ失敗した場合は、成功した方の結果のみ使用する。
```

**変更後:**
```
**失敗時のフォールバック:**
エージェントが失敗した場合（タイムアウト、エラー等）は、従来通りメイン context で Grep/Read による最低限の調査を行う。一部のみ失敗した場合は、成功した方の結果のみ使用する。
```

**Step 2: S3 セクションに Impact Analysis と Must-Verify Checklist を追加**

**変更前:**
```
### S3: 調査結果の記録

S1・S2 で確認した内容を、設計書に以下のセクションとして含める:

- **前提条件** — 新機能が依存する既存の制約・ルール
- **影響範囲** — 変更が波及する可能性のあるモジュール・テーブル一覧
```

**変更後:**
```
### S3: 調査結果の記録

S1・S2 で確認した内容を、設計書に以下のセクションとして含める:

- **前提条件** — 新機能が依存する既存の制約・ルール
- **影響範囲** — 変更が波及する可能性のあるモジュール・テーブル一覧
- **Impact Analysis** — impact-analyzer の出力を構造化して記録する。以下のサブセクションを含む:
  - **Reverse Dependencies** — 変更対象の呼び出し元一覧（ファイル:行番号、依存の強さ）
  - **Shared State** — 共有リソース一覧（種別、制約、使われ方）
  - **Implicit Contracts** — 暗黙の制約一覧（ファイル:行番号、依存先、違反時の影響）
  - **Side Effect Risks** — 副作用リスクシナリオ（severity、発生条件、影響範囲）
- **Must-Verify Checklist** — 実装・テスト時に確認すべき事項のチェックリスト（impact-analyzer の出力から生成）。後続フェーズ（Phase 4 の implementation-review-consistency、Phase 7 の code-review-impact）で参照される
```

**Step 3: 検証 — 変更後のファイルを確認**

Run: `grep -c "impact-analyzer" ~/.dotfiles/claude/skills/feature-dev/references/brainstorming-supplement.md`
Expected: 5 以上（複数箇所で参照）

Run: `grep "Must-Verify" ~/.dotfiles/claude/skills/feature-dev/references/brainstorming-supplement.md`
Expected: Must-Verify Checklist の記述が含まれる

**Step 4: コミット**

```bash
git add ~/.dotfiles/claude/skills/feature-dev/references/brainstorming-supplement.md
git commit -m "feat: integrate impact-analyzer into Phase 1 exploration and design doc template"
```

---

### Task 4: spec-review-consistency エージェント改修

**Files:**
- Modify: `~/.claude/agents/spec-review-consistency.md`

**Step 1: Review Checklist に Impact Analysis 検証を追加**

Review Checklist の項目 6 (Impact analysis) を強化し、項目 7 を追加する。

**変更前（項目 6）:**
```
6. **Impact analysis** — 設計変更の影響範囲が十分に特定されているか。変更対象のモデル・コントローラ・ジョブ等を起点に、呼び出し元・依存先・同じテーブルを参照する箇所を調査し、設計書が見落としている影響箇所がないか検証する
```

**変更後（項目 6 + 7）:**
```
6. **Impact analysis** — 設計変更の影響範囲が十分に特定されているか。変更対象のモデル・コントローラ・ジョブ等を起点に、呼び出し元・依存先・同じテーブルを参照する箇所を調査し、設計書が見落としている影響箇所がないか検証する
7. **Impact Analysis section completeness** — 設計書に Impact Analysis セクション（Reverse Dependencies, Shared State, Implicit Contracts, Side Effect Risks）が存在し、各項目が具体的に記述されているか。抽象的な記述（「他モジュールに影響する可能性がある」等）ではなく、具体的なファイル:行番号・リソース名・シナリオが含まれているか。Must-Verify Checklist が存在し、実装・テスト時に検証可能な具体的項目が列挙されているか。各項目について実際にコードを Grep/Read して記述の正確性を検証する。前提条件セクションと Implicit Contracts に矛盾がないか確認する
```

**Step 2: REJECT 基準に Impact Analysis 関連を追加**

**変更前（REJECT 基準）:**
```
### REJECT 基準（1つでも該当すれば REJECT を推奨）
- 既存コードの構造・パターンと矛盾する設計 → severity: high
- TODO/TBD/要確認の未解決マーカーが残存 → severity: high
- 設計変更の影響範囲に見落としがある（呼び出し元・依存先が未特定） → severity: high
```

**変更後:**
```
### REJECT 基準（1つでも該当すれば REJECT を推奨）
- 既存コードの構造・パターンと矛盾する設計 → severity: high
- TODO/TBD/要確認の未解決マーカーが残存 → severity: high
- 設計変更の影響範囲に見落としがある（呼び出し元・依存先が未特定） → severity: high
- Impact Analysis セクションが存在しない、または不完全（Reverse Dependencies, Shared State, Implicit Contracts, Side Effect Risks のいずれかが欠落） → severity: high
- 影響範囲の記述が抽象的（具体的なファイル:行番号、リソース名、呼び出し元の記載がない） → severity: high

### WARNING 基準
- 命名規則の不一致（既存の camelCase/snake_case パターンとの乖離） → severity: medium
- 「〜と仮定する」で済ませている判断で、仮定が検証可能なもの → severity: medium
- Must-Verify Checklist が存在しない → severity: medium
```

**Step 3: 検証 — 変更後のファイルを確認**

Run: `grep "Impact Analysis" ~/.claude/agents/spec-review-consistency.md`
Expected: 複数行ヒット

Run: `grep -c "severity: high" ~/.claude/agents/spec-review-consistency.md`
Expected: 5（既存3 + 追加2）

**Step 4: コミット**

```bash
git add ~/.claude/agents/spec-review-consistency.md
git commit -m "feat: add Impact Analysis completeness checks to spec-review-consistency"
```

---

### Task 5: implementation-review-consistency エージェント改修

**Files:**
- Modify: `~/.claude/agents/implementation-review-consistency.md`

**Step 1: Review Checklist に Impact Analysis カバレッジを追加**

**変更前:**
```
## Review Checklist

1. **Design coverage** — 設計書の全要件が計画のタスクにマッピングされているか
2. **Pattern alignment** — 既存コードの構造・パターンに沿ったファイル配置が計画されているか
3. **Convention compliance** — プロジェクトの CLAUDE.md に定義された規約に沿っているか
4. **Missing requirements** — 設計書にあるが計画に漏れている要件がないか
```

**変更後:**
```
## Review Checklist

1. **Design coverage** — 設計書の全要件が計画のタスクにマッピングされているか
2. **Pattern alignment** — 既存コードの構造・パターンに沿ったファイル配置が計画されているか
3. **Convention compliance** — プロジェクトの CLAUDE.md に定義された規約に沿っているか
4. **Missing requirements** — 設計書にあるが計画に漏れている要件がないか
5. **Impact coverage** — 設計書の Impact Analysis セクションの Side Effect Risks に対応するタスクが計画に含まれているか。Must-Verify Checklist の各項目がテストケースまたは実装タスクにマッピングされているか
```

**Step 2: REJECT 基準に Impact Analysis 関連を追加**

**変更前:**
```
### REJECT 基準（1つでも該当すれば REJECT を推奨）
- 設計要件が計画タスクに未マッピング（設計書にある要件が計画に含まれていない） → severity: high
- CLAUDE.md 規約の明確な違反 → severity: high
```

**変更後:**
```
### REJECT 基準（1つでも該当すれば REJECT を推奨）
- 設計要件が計画タスクに未マッピング（設計書にある要件が計画に含まれていない） → severity: high
- CLAUDE.md 規約の明確な違反 → severity: high
- Impact Analysis の Side Effect Risks に対応するタスクが計画にない（リスクへの対処が計画されていない） → severity: high
- Must-Verify Checklist の項目がテストケースにマッピングされていない（検証手段が計画されていない） → severity: high
```

**Step 3: 検証 — 変更後のファイルを確認**

Run: `grep "Impact" ~/.claude/agents/implementation-review-consistency.md`
Expected: Impact coverage, Impact Analysis の記述がヒット

Run: `grep -c "severity: high" ~/.claude/agents/implementation-review-consistency.md`
Expected: 4（既存2 + 追加2）

**Step 4: コミット**

```bash
git add ~/.claude/agents/implementation-review-consistency.md
git commit -m "feat: add Impact Analysis coverage checks to implementation-review-consistency"
```

---

### Task 6: code-review/SKILL.md 改修

**Files:**
- Modify: `~/.dotfiles/claude/skills/code-review/SKILL.md`

**Step 1: Phase 2 のタイトルとエージェント数を更新**

**変更前 (行 42-44):**
```
## Phase 2: Parallel Review (6+1 perspectives)

5つの Agent 観点を `iterations` 回ずつ、simplify ×1（`codex_enabled` 時は Codex ×1 を追加）で **並列** 起動する。合計エージェント数: 5 × iterations + 1 (simplify) + (codex ? 1 : 0)。すべて `run_in_background: true` を使用し、結果を収集する。
```

**変更後:**
```
## Phase 2: Parallel Review (7+1 perspectives)

6つの Agent 観点を `iterations` 回ずつ、simplify ×1（`codex_enabled` 時は Codex ×1 を追加）で **並列** 起動する。合計エージェント数: 6 × iterations + 1 (simplify) + (codex ? 1 : 0)。すべて `run_in_background: true` を使用し、結果を収集する。
```

**Step 2: Phase 2 に code-review-impact エージェントセクションを追加**

行 58 の `### 2-2 ~ 2-6.` セクションを `### 2-2 ~ 2-7.` に変更し、エージェント名リストに `code-review-impact` を追加する。

**変更前 (行 58-62):**
```
### 2-2 ~ 2-6. code-review-quality / code-review-security / code-review-performance / code-review-test / code-review-ai-antipattern

各エージェントに対して Agent tool を使用する。`subagent_type` にエージェント名（`code-review-quality`, `code-review-security`, `code-review-performance`, `code-review-test`, `code-review-ai-antipattern`）を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

`iterations > 1` の場合、各エージェント（code-review-quality, code-review-security, code-review-performance, code-review-test, code-review-ai-antipattern）について、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。
```

**変更後:**
```
### 2-2 ~ 2-7. code-review-quality / code-review-security / code-review-performance / code-review-test / code-review-ai-antipattern / code-review-impact

各エージェントに対して Agent tool を使用する。`subagent_type` にエージェント名（`code-review-quality`, `code-review-security`, `code-review-performance`, `code-review-test`, `code-review-ai-antipattern`, `code-review-impact`）を指定し、prompt に `changed_files` と `diff_content` を含め、findings を JSON で返すよう指示する。

`code-review-impact` エージェントには、設計書の Impact Analysis セクション（存在する場合）も追加コンテキストとして渡す。設計書パスは feature-dev パイプラインから `artifacts.design_doc` で伝播される。設計書が見つからない場合は Impact Analysis コンテキストなしで起動する（Must-Verify 消化チェックはスキップされる）。

`iterations > 1` の場合、各エージェント（code-review-quality, code-review-security, code-review-performance, code-review-test, code-review-ai-antipattern, code-review-impact）について、同一の prompt で `iterations` 回起動する。各イテレーションは独立した Agent tool 呼び出しとし、全て `run_in_background: true` で並列起動する。
```

**Step 3: Phase 2 の結果収集セクションを更新**

**変更前 (行 129):**
```
すべて（6つ、または `codex_enabled` 時は7つ）の完了を待つ。
```

**変更後:**
```
すべて（7つ、または `codex_enabled` 時は8つ）の完了を待つ。
```

**Step 4: Phase 4 の category リストを更新**

**変更前 (行 318):**
```
**その他の findings (quality, security, performance, test, ai-antipattern, codex, codex-meta) の場合:**
```

**変更後:**
```
**その他の findings (quality, security, performance, test, ai-antipattern, impact, codex, codex-meta) の場合:**
```

**Step 5: description（frontmatter）を更新**

**変更前 (行 3-5):**
```
description: >-
  多角的コードレビューワークフロー。6つの観点（simplify, code-quality, code-security,
  code-performance, code-test, ai-antipattern）で並列レビューし、統合レポートから承認された指摘を修正する。
```

**変更後:**
```
description: >-
  多角的コードレビューワークフロー。7つの観点（simplify, code-quality, code-security,
  code-performance, code-test, ai-antipattern, code-impact）で並列レビューし、統合レポートから承認された指摘を修正する。
```

**Step 6: 検証 — 変更後のファイルを確認**

Run: `grep "code-review-impact" ~/.dotfiles/claude/skills/code-review/SKILL.md`
Expected: 複数行ヒット

Run: `grep "7+1" ~/.dotfiles/claude/skills/code-review/SKILL.md`
Expected: 1行ヒット（Phase 2 タイトル）

**Step 7: コミット**

```bash
git add ~/.dotfiles/claude/skills/code-review/SKILL.md
git commit -m "feat: add code-review-impact as 7th review perspective in code-review"
```

---

### Task 7: smoke-test/SKILL.md 改修

**Files:**
- Modify: `~/.dotfiles/claude/skills/smoke-test/SKILL.md`

**Step 1: frontmatter の description を更新**

**変更前 (行 3-5):**
```
description: >-
  Playwright ベースのローカルスモークテスト。dev サーバー起動 → アドホックテスト生成・実行 →
  VRT 差分チェック → E2E 実行 + フレーキー検出の4ステップを実行する。
```

**変更後:**
```
description: >-
  Browser Use CLI ベースのローカルスモークテスト。dev サーバー起動 → アドホックテスト生成・実行 →
  VRT 差分チェック → E2E 実行 + フレーキー検出の4ステップを実行する。
```

**Step 2: 冒頭の説明を更新**

**変更前 (行 12):**
```
ローカル環境で Playwright を使い、実装した機能の動作確認・VRT 差分チェック・E2E フレーキー検出を自律的に実行する。
```

**変更後:**
```
ローカル環境で Browser Use CLI を使い、実装した機能の動作確認・VRT 差分チェック・E2E フレーキー検出を自律的に実行する。
```

**Step 3: Step 1 のサーバー起動確認を更新**

**変更前 (行 62):**
```
起動確認: Playwright で `localhost:<port>` にアクセスし、`networkidle` 待機する。30秒タイムアウト → PAUSE。
```

**変更後:**
```
起動確認: `browser-use open http://localhost:<port>` でアクセスし、ページ読み込みを確認する。`browser-use state` でページ要素が取得できることを検証する。30秒タイムアウト → PAUSE。
```

**Step 4: Step 2 を全面改修（Browser Use CLI ベース）**

Step 2 セクション全体（行 68-99）を以下に置換する:

```markdown
## Step 2: Ad-hoc Smoke Test

設計書と実装差分からスモークテストシナリオを自動生成し、Browser Use CLI で直接実行する。

### 前提条件チェック

`browser-use --version` を実行し、Browser Use CLI がインストールされているか確認する。

未インストールの場合:
```
browser-use が見つかりません。以下でインストールしてください:
  uvx browser-use install
```
→ PAUSE。

### 差分取得

| 条件 | diff コマンド |
|------|-------------|
| `--diff-base <branch>` 指定 | `git diff <branch>...HEAD` |
| (なし) | `git diff HEAD~1` |

`--design <path>` 指定時は設計書も Read で読み込み、Impact Analysis セクションを抽出してシナリオ生成の精度と影響範囲テストに活用する。

### シナリオ生成

以下の5観点でシナリオを自然言語で生成する。

1. **ナビゲーション確認** — ページ遷移・表示が正常であること
2. **ユーザーインタラクション** — クリック、入力、フォーム送信が動作すること
3. **エラー不在確認** — コンソールエラー・ネットワークエラーが発生しないこと
4. **レスポンシブ確認** — desktop: 1280x720, mobile: 375x667 の両方で表示が崩れないこと
5. **影響波及テスト** — Impact Analysis の Reverse Dependencies / Side Effect Risks に基づき、変更の波及先が正常に動作すること

### 実行

LLM が Browser Use CLI コマンドを Bash ツール経由で逐次実行し、各シナリオを検証する。

**使用コマンド:**
- `browser-use open <url>` — ページ遷移
- `browser-use state` — 現在のページ要素一覧を取得（クリック可能な要素のインデックス付き）
- `browser-use click <index>` — 要素をクリック
- `browser-use type "<text>"` — テキスト入力
- `browser-use screenshot <filename>` — スクリーンショット保存
- `browser-use close` — ブラウザを閉じる

**実行フロー（各シナリオ）:**
1. `browser-use open <target_url>` でページ遷移
2. `browser-use state` でページ状態を取得
3. 操作（click/type）を実行
4. `browser-use state` で操作結果を確認
5. `browser-use screenshot smoke-<scenario_name>.png` で証跡を保存
6. LLM が state の内容とスクリーンショットから PASS/FAIL を判定

**失敗時:** シナリオを修正し再実行する（最大2回）。2回失敗 → FAIL。

**アナウンス:** 「Step 2 完了。<N>/<M> シナリオ PASS。Step 3: VRT Diff Check に進みます」
```

**Step 5: Step 3 (VRT) の実行方法を更新**

Step 3 の VRT は既存ツール（reg-suit 等）がある場合はそのまま使用し、ない場合は `browser-use screenshot` で代替する。VRT 設定の自動検出ロジックはそのまま維持する。

**変更前 (行 120-123):**
```
差分あり → 差分画像を Read で提示 → AskUserQuestion で更新確認:

- **承認** → ベースライン更新 & コミット
- **拒否** → レポートに記録のみ
```

変更なし（このセクションは維持）。

**Step 6: Error Handling を更新**

**変更前 (行 240-241):**
```
| 2 | Playwright スクリプト実行エラー | 修正 → 再実行（最大2回） |
```

**変更後:**
```
| 2 | Browser Use CLI 実行エラー | 修正 → 再実行（最大2回） |
```

**変更前 (行 244):**
```
| 全体 | Playwright 未インストール | インストール提案、PAUSE |
```

**変更後:**
```
| 全体 | Browser Use CLI 未インストール | `uvx browser-use install` を提案、PAUSE |
```

**Step 7: webapp-testing 参照を削除**

**変更前 (行 60):**
```
サーバー起動には webapp-testing スキルの `with_server.py` パターンを活用する。
```

**変更後:**
```
サーバー起動にはバックグラウンドプロセスとして起動する（`run_in_background: true`）。
```

**Step 8: 検証 — 変更後のファイルを確認**

Run: `grep "browser-use" ~/.dotfiles/claude/skills/smoke-test/SKILL.md`
Expected: 複数行ヒット（CLI コマンドの各種参照）

Run: `grep "Playwright" ~/.dotfiles/claude/skills/smoke-test/SKILL.md`
Expected: Step 3, Step 4 の既存 E2E ツール検出部分のみ（Step 2 からは除去済み）

Run: `grep "影響波及" ~/.dotfiles/claude/skills/smoke-test/SKILL.md`
Expected: 1行ヒット（5番目の観点）

**Step 9: コミット**

```bash
git add ~/.dotfiles/claude/skills/smoke-test/SKILL.md
git commit -m "feat: replace Playwright code gen with Browser Use CLI in smoke-test Step 2"
```

---

### Task 8: 統合検証

**Files:**
- Read: 全改修ファイル

**Step 1: 全ファイルの cross-reference 検証**

以下の参照が正しく繋がっているか確認する:

| 参照元 | 参照先 | 確認事項 |
|--------|--------|---------|
| brainstorming-supplement.md | impact-analyzer.md | S1 で参照するエージェント名が agent 定義の name と一致 |
| code-review/SKILL.md | code-review-impact.md | Phase 2 で参照するエージェント名が agent 定義の name と一致 |
| spec-review-consistency.md | Impact Analysis セクション | REJECT 基準が brainstorming-supplement.md の S3 で定義されるセクション名と一致 |
| implementation-review-consistency.md | Must-Verify Checklist | REJECT 基準が brainstorming-supplement.md の S3 で定義されるセクション名と一致 |
| code-review-impact.md | Must-Verify Checklist | チェック観点が brainstorming-supplement.md の S3 で定義されるセクション名と一致 |
| smoke-test/SKILL.md | Impact Analysis セクション | 5番目の観点が brainstorming-supplement.md の S3 で定義されるセクション名と一致 |

Run: `grep -r "impact-analyzer" ~/.claude/agents/ ~/.dotfiles/claude/skills/`
Expected: brainstorming-supplement.md と impact-analyzer.md でヒット

Run: `grep -r "code-review-impact" ~/.claude/agents/ ~/.dotfiles/claude/skills/`
Expected: code-review/SKILL.md と code-review-impact.md でヒット

Run: `grep -r "Must-Verify" ~/.claude/agents/ ~/.dotfiles/claude/skills/`
Expected: brainstorming-supplement.md, spec-review-consistency.md, implementation-review-consistency.md, code-review-impact.md, impact-analyzer.md でヒット

**Step 2: frontmatter の YAML 構文検証**

全エージェント定義の frontmatter が正しく閉じられているか確認:

Run: `for f in ~/.claude/agents/impact-analyzer.md ~/.claude/agents/code-review-impact.md; do echo "=== $f ==="; head -4 $f; echo "---"; done`
Expected: 各ファイルで `---` が開始行と3-4行目に存在

**Step 3: コミット（全体の統合確認完了を記録）**

```bash
git commit --allow-empty -m "chore: verify cross-references across impact analysis harness"
```
