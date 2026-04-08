# Triage Parallel Exploration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Phase 2 of `/triage` SKILL.md to parallelize context explorations via sub-agents with a confirmation gate.

**Architecture:** Single-file edit to `SKILL.md`. Replace the monolithic Phase 2 section with 3 sub-steps (2a: Planning, 2b: Parallel Execution, 2c: Findings Confirmation). Add a Red Flags entry for agent output hygiene.

**Tech Stack:** Markdown (SKILL.md authoring)

**Spec:** `docs/superpowers/specs/2026-04-08-triage-parallel-exploration-design.md`

---

### Task 1: Replace Phase 2 section with 2a/2b/2c structure

**Files:**
- Modify: `claude/skills/triage/SKILL.md:50-103`

- [ ] **Step 1: Replace Phase 2 section**

Replace the entire Phase 2 section (lines 50-103, from `## Phase 2: Context Exploration` up to but not including `## Phase 3: Analysis`) with the following:

```markdown
## Phase 2: Context Exploration

**アナウンス:** 「Phase 2: Context Exploration — 周辺コンテキストを探索します」

Phase 1 で取得したデータを分析し、並列エージェントで探索を実行する。3 サブステップで構成される。

### Phase 2a: Exploration Planning

Phase 1 のデータから以下を抽出する:
1. 報告者（誰が報告しているか）
2. 対象（何についての報告か — 顧客名、機能名、エラー内容等）
3. 緊急度の手がかり（「至急」「本番障害」等のキーワード）

データ内容に応じて追加探索オプションを提案する。探索の種類と深さは LLM がデータ内容に応じて判断する。固定リストではない。

典型的な探索候補:
- コミュニケーションツール内の関連メッセージ検索
- Issue/PR の類似報告・過去の対応履歴
- コードベースの関連箇所・最近の変更
- 実行環境・データストア・エラートラッキング等の外部システム確認

以下のフォーマットで提案し、AskUserQuestion で選択を取得する:

` ` `
## データソース要約
- ソース: [ソース種別と概要]
- 報告者: [誰が]
- 内容: [何を報告しているか]

## 探索提案
以下の追加調査を提案します:
1. [推奨] ...
2. [推奨] ...
3. [任意] ...

実行する番号を選択してください（例: 1,2 / all / none）
` ` `

受け付ける入力:
- `none` → Phase 2b/2c をスキップし、Phase 1 のデータのみで Phase 3 に進む
- `all` → 全探索を並列実行
- カンマ区切りの番号（例: `1,2`） → 該当番号の探索を並列実行

ユーザーが番号選択と共に補足テキストを追加した場合、Phase 3 の分析に加味する。

### Phase 2b: Parallel Execution

承認された探索を 1 候補 = 1 Agent として並列 dispatch する。

**エージェント構成:**
- 各エージェントには以下を渡す:
  - Phase 1 の取得データ（コンテキスト共有）
  - 探索の具体的な指示（例: 「Linear で [トピック] に関連するチケットを検索」）
  - 利用するツールの指定（slackcli, Grep, linear CLI 等）
- エージェント数の上限なし（承認された探索数 = エージェント数）

**エージェントの責務:**
- 割り当てられた 1 つの探索を実行し、結果を返す。それ以外はやらない
- 探索失敗時は「取得できなかった」旨を返す（該当探索をスキップして続行）

**オーケストレーターの責務:**
- 全エージェントの完了を待つ
- 各エージェントの結果を自身で統合・要約する
- エージェントの生出力をそのまま Phase 3 に転送しない

### Phase 2c: Findings Confirmation

全探索結果のサマリーを提示し、ユーザーに正確性を確認する。

以下のフォーマットで提示し、AskUserQuestion で承認を取得する:

` ` `
## 探索結果サマリー

### 1. [探索名]
- 取得元: [URL or 検索クエリ]
- 要約: [2-3行の要約]
- 関連度: 高 / 中 / 低

### 2. [探索名]
- 取得元: ...
- 要約: ...
- 関連度: ...

---
この内容で分析に進みますか？（修正があれば指示してください）
` ` `

受け付ける入力:
- 承認 → Phase 3 に進む
- 修正指示（例: 「1 のスレッドは違う、正しくは #channel の昨日のスレッド」）→ 該当探索のみ再実行し、再度確認ゲートを提示
- `none` → 全探索結果を破棄し、Phase 1 のデータのみで Phase 3 に進む

**再実行ルール:**
- 修正対象の探索のみ再実行する（他の探索結果は保持）
- 再実行は並列ではなく単発（1 探索の修正のため）
- 再実行後、再度確認ゲートを全体提示する
```

- [ ] **Step 2: Verify no broken section references**

Run: `grep -n "Phase 2" claude/skills/triage/SKILL.md`

Expected: Phase 2 references appear in the new section (lines ~50-140) and in the error handling table (line ~180). No orphaned references to old sub-sections like `### 探索実行` or `### ユーザー対話`.

- [ ] **Step 3: Commit**

```bash
git add claude/skills/triage/SKILL.md
git commit -m "feat(triage): parallelize Phase 2 exploration with sub-agents

Replace sequential Phase 2 with 3 sub-steps:
- 2a: Exploration Planning (unchanged proposal flow)
- 2b: Parallel Execution (1 exploration = 1 agent)
- 2c: Findings Confirmation (user verifies before analysis)"
```

---

### Task 2: Add Red Flags entry for agent output hygiene

**Files:**
- Modify: `claude/skills/triage/SKILL.md:187-190` (Red Flags "Never" list)

- [ ] **Step 1: Add Red Flags entry**

Add the following line after the existing "Never" list items (after line 190 `- 取得できなかったデータを推測で補完する`):

```markdown
- Phase 2b エージェントの生出力を統合・要約せずに Phase 3 に転送する
```

- [ ] **Step 2: Verify Red Flags section**

Run: `grep -A 6 "^## Red Flags" claude/skills/triage/SKILL.md`

Expected output includes 4 "Never" items:
1. ユーザー承認なしに Linear Issue を作成する
2. Phase 2 の探索提案をスキップする
3. 取得できなかったデータを推測で補完する
4. Phase 2b エージェントの生出力を統合・要約せずに Phase 3 に転送する

- [ ] **Step 3: Commit**

```bash
git add claude/skills/triage/SKILL.md
git commit -m "feat(triage): add red flag for raw agent output forwarding"
```

---

### Task 3: Final verification

- [ ] **Step 1: Read the full SKILL.md and verify structural integrity**

Run: `cat -n claude/skills/triage/SKILL.md`

Verify:
- Phase 1 → Phase 2 (2a → 2b → 2c) → Phase 3 → Phase 4 の順序が正しい
- 各 Phase のアナウンスフォーマットが統一されている
- コードブロックが正しく閉じている
- エラーハンドリング表の Phase 2 行が新構造と整合している

- [ ] **Step 2: Check for trailing whitespace or formatting issues**

Run: `grep -n '  $' claude/skills/triage/SKILL.md || echo "No trailing whitespace"`

Expected: No trailing whitespace (or only intentional markdown line breaks).
