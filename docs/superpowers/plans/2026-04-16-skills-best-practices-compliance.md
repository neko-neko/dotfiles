# Skills Best Practices 準拠化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `claude/skills/` 配下 8 スキルの SKILL.md を Anthropic Skill Authoring Best Practices に準拠させる。

**Architecture:** 単純な Markdown 編集タスク群。doc-audit への frontmatter 追加、handover の progressive disclosure 化（JSON スキーマを references/ に外出し）、4 スキルの description 調整、slackcli の独自 metadata 削除。各編集は Edit で行い、検証は grep/wc/head コマンドで行う。

**Tech Stack:** Markdown, YAML frontmatter, Bash (grep/wc/head), Edit/Write/Read ツール。

**Spec:** `docs/superpowers/specs/2026-04-16-skills-best-practices-compliance-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `claude/skills/handover/references/project-state-schema.md` | project-state.json の JSON スキーマ、マージルール、Phase Summary YAML フォーマット、handover.md 出力フォーマットを保持する参照ドキュメント |
| Modify | `claude/skills/doc-audit/SKILL.md` | YAML frontmatter を追加（現在完全欠落） |
| Modify | `claude/skills/handover/SKILL.md` | description 更新、JSON スキーマ等のインラインブロック削除、参照文に置換 |
| Modify | `claude/skills/continue/SKILL.md` | description 更新 |
| Modify | `claude/skills/linear-refresh/SKILL.md` | description 更新 |
| Modify | `claude/skills/slackcli/SKILL.md` | frontmatter から `metadata` ブロック削除 |

## Baseline（現状行数）

```
continue        191
doc-audit       107
doc-check        64  (変更なし)
handover        305  → 約 215 へ短縮
linear-refresh  149
slackcli        128
triage          239  (変更なし)
weekly-sync     275  (変更なし)
合計          1,458
```

## Commit Policy

各タスクは atomic に 1 commit。コミットプレフィックスは既存履歴に倣い `chore(skills):`。

---

## Task 1: doc-audit の frontmatter 追加

**Files:**
- Modify: `claude/skills/doc-audit/SKILL.md:1-1`

- [ ] **Step 1: 現状を確認し frontmatter 欠落を検証する**

```bash
head -3 /Users/nishikataseiichi/.dotfiles/claude/skills/doc-audit/SKILL.md
```

Expected: 1 行目が `ドキュメント監査スキル。4 Layer 構造で...` で、`---` で始まる frontmatter が存在しない。

- [ ] **Step 2: frontmatter を追加する（Edit）**

`old_string` は SKILL.md の冒頭 1 行目:
```
ドキュメント監査スキル。4 Layer 構造でドキュメントの陳腐化・欠落・矛盾を検出し、ユーザー承認後に修正する。
```

`new_string`:
```
---
name: doc-audit
description: >-
  md ドキュメントの陳腐化・欠落・矛盾を 4 Layer 構造で検出し、ユーザー承認後に修正する。
  depends-on 検証、coverage チェック、business-rule/architecture の未文書化知識検出、
  readme/CLAUDE.md のメタ整合検査を行う。/doc-audit で起動、または大規模なコード変更後に
  ドキュメント整合性を確認したい時に使用する。
---

ドキュメント監査スキル。4 Layer 構造でドキュメントの陳腐化・欠落・矛盾を検出し、ユーザー承認後に修正する。
```

- [ ] **Step 3: frontmatter 追加を検証する**

```bash
head -10 /Users/nishikataseiichi/.dotfiles/claude/skills/doc-audit/SKILL.md
```

Expected: 1 行目が `---`、2 行目が `name: doc-audit`、3 行目が `description: >-` で始まる。

さらに frontmatter 構造の正当性を確認:
```bash
awk '/^---$/{c++; next} c==1' /Users/nishikataseiichi/.dotfiles/claude/skills/doc-audit/SKILL.md | head -10
```

Expected: `name: doc-audit` と `description:` の内容が表示される。

- [ ] **Step 4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles && git add claude/skills/doc-audit/SKILL.md && git commit -m "$(cat <<'EOF'
chore(skills): add missing frontmatter to doc-audit SKILL.md

doc-audit の SKILL.md に YAML frontmatter (name, description) が欠落していた。
Anthropic の Skill authoring best practices では frontmatter は必須要件のため追加する。
EOF
)"
```

---

## Task 2: handover の JSON スキーマ外出し + description 更新

**Files:**
- Create: `claude/skills/handover/references/project-state-schema.md`
- Modify: `claude/skills/handover/SKILL.md` (description 更新、JSON スキーマ + マージルール + Phase Summary YAML + handover.md 出力フォーマットを削除し参照文に置換)

- [ ] **Step 1: handover/SKILL.md 現状を確認する**

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/handover/SKILL.md
```

Expected: `305 ...`

```bash
ls /Users/nishikataseiichi/.dotfiles/claude/skills/handover/
```

Expected: `SKILL.md`, `scripts/` のみ（`references/` は未作成）。

- [ ] **Step 2: references/ ディレクトリと project-state-schema.md を作成する**

`mkdir` は `Write` ツールのファイル作成で暗黙に行われるため、`Write` ツールで以下の内容のファイルを作成する:

**Path:** `/Users/nishikataseiichi/.dotfiles/claude/skills/handover/references/project-state-schema.md`

**Content:**
````markdown
# Project State Schema

`project-state.json` の完全な JSON スキーマ、マージルール、Phase Summary フォーマット、および handover.md 出力フォーマットを定義する。handover スキルの本体である [SKILL.md](../SKILL.md) から参照される。

## Contents

- project-state.json JSON スキーマ
- マージルール（既存 project-state.json との統合）
- Phase Summary YAML フォーマット（pipeline ワークフロー時）
- handover.md 出力フォーマット

## project-state.json JSON スキーマ

```json
{
  "version": 5,
  "generated_at": "ISO8601 現在時刻",
  "session_id": "現在のセッションID（不明なら unknown）",
  "status": "READY | ALL_COMPLETE",
  "workspace": {
    "root": "リポジトリまたは worktree のルートパス",
    "branch": "ブランチ名",
    "is_worktree": false
  },
  "active_tasks": [
    {
      "id": "T1",
      "description": "タスクの説明",
      "status": "done | in_progress | blocked",
      "commit_sha": "コミットした場合のSHA（done の場合のみ）",
      "file_paths": ["関連ファイルパス"],
      "next_action": "次にやるべき具体的なアクション（in_progress/blocked の場合）",
      "blockers": ["ブロッカーの説明（blocked の場合）"],
      "attempted_approaches": [
        {
          "approach": "試みたアプローチの説明",
          "result": "failed | abandoned | partial",
          "reason": "なぜ失敗/断念したか",
          "learnings": "次に活かすべき知見"
        }
      ],
      "last_touched": "ISO8601"
    }
  ],
  "recent_decisions": [
    {
      "decision": "このセッションで決めたこと",
      "rationale": "その理由",
      "date": "ISO8601"
    }
  ],
  "architecture_changes": [
    {
      "commit_sha": "SHA",
      "summary": "変更の要約",
      "files_changed": ["変更ファイル"],
      "date": "ISO8601"
    }
  ],
  "known_issues": [
    {
      "description": "既知の問題",
      "severity": "high | medium | low",
      "related_files": ["関連ファイル"]
    }
  ],
  "phase_observations": [
    {
      "phase": "execute",
      "recorded_at": "ISO8601",
      "observations": [
        {
          "criteria_id": "EXE-08",
          "severity": "quality | warning",
          "observation": "所見の内容",
          "recommendation": "推奨アクション"
        }
      ]
    }
  ],
  "session_notes": [
    {
      "recorded_at": "ISO8601",
      "category": "insight | directive | concern",
      "content": "メモの内容",
      "relates_to_phase": "execute"
    }
  ],
  "session_hash": "",
  "linear": {
    "issue_id": "Linear チケットID (例: PROJ-123)。linear-sync supplement 使用時のみ設定。null または未設定の場合、sync は無効",
    "last_synced_phase": "execute",
    "document_id": "Linear Document ID。linear-sync supplement が作成した Workflow Report Document の ID。sync_workflow_start で設定される"
  },
  "phase_summaries": {
    "design": "phase-summaries/design.yml",
    "spec-review": "phase-summaries/spec-review.yml"
  },
  "session": {
    "session_id": "<CLAUDE_SESSION_ID>",
    "resume_hint": "<次フェーズの概要と注意点>"
  }
}
```

### status の自動判定

- `active_tasks` の全タスクが `done` → `status` を `ALL_COMPLETE` に設定
- それ以外 → `READY`

## マージルール（既存 project-state.json との統合）

| フィールド | マージ挙動 |
|-----------|-----------|
| `active_tasks` | 同じ ID のタスクは上書き、新しいタスクは追加 |
| `recent_decisions` | 追記（重複しない） |
| `architecture_changes` | 追記（直近 10 件を保持、古い順に削除） |
| `attempted_approaches` | 同一タスク ID のタスクでは追記（重複排除、approach が同じエントリは上書き） |
| `known_issues` | 解決済みなら削除、新規は追加 |
| `phase_observations` | 同一 phase のエントリは上書き、新規 phase は追加。各 phase の observations は最大 5 件（severity: warning > quality の順で保持） |
| `session_notes` | 追記（content 先頭 50 文字一致で重複排除）。セッションあたり最大 10 件 |
| `linear` | オブジェクト全体を新しい値で上書き（`issue_id`, `last_synced_phase`, `document_id`） |
| `phase_summaries` | 新しいエントリを追記（既存キーは上書きしない） |
| `session` | 新しい値で上書き |

## Phase Summary YAML フォーマット（pipeline ワークフロー時）

`project-state.json` の `pipeline` フィールドが存在する場合（feature-dev / debug-flow）、`.agents/handover/{branch}/{fingerprint}/phase-summaries/` ディレクトリに以下のフォーマットで書き出す。

```yaml
phase: N
phase_name: <name>
status: completed | failed
timestamp: <ISO8601>
attempt: N
audit_verdict: PASS | FAIL

artifacts:
  <name>:
    type: file | git_range | inline
    value: <参照先>

decisions: []
concerns:
  - target_phase: <phase_id>
    content: <内容>
directives:
  - target_phase: <phase_id>
    content: <内容>

evidence:
  - type: <種別>
    content: <内容> | local_path: <パス>
    linear_sync: inline | attached | reference_only

regate_history: []
```

### session フィールドの生成

Phase Summary 書き出し後、`project-state.json` の `session` フィールドを以下で更新する:

- `session_id`: `${CLAUDE_SESSION_ID}`
- `resume_hint`: current_phase の概要と前フェーズからの concerns/directives

## handover.md 出力フォーマット

`project-state.json` から自動生成される人間向けビュー。直接編集しないこと。

```
# Session Handover
> Generated: {generated_at}
> Session: {session_id}
> Status: {status}

## Completed
- [ID] タスク説明 (commit_sha)

## Remaining
- [ID] **status** タスク説明
  - files: ファイルパス
  - next: 次のアクション
  （attempted_approaches がある場合）
  - tried: アプローチ説明 → result: 理由 (知見)
  （blocked の場合）
  - blocker: ブロッカー

## Blockers
- ブロッカーの一覧（なければ「なし」）

## Context
- recent_decisions の内容

## Architecture Changes (Recent)
- commit_sha: 要約

## Observations (from Audit)
- [<phase_id>] criteria_id: observation（recommendation）

## Session Notes
- [category] content（<phase_id>）

## Phase Progress（pipeline ワークフロー時のみ）
- [design] ✅ (spec: <path>)
- [spec-review] ✅ (findings: 0 blocker)
- [plan] ✅ (plan: <path>)
- [execute] ✅
  - Concerns: <concerns for later phases>
→ Current Phase: <phase_id>

## Known Issues
- [severity] 問題の説明（なければ「なし」）
```
````

- [ ] **Step 3: ファイル作成を検証する**

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/handover/references/project-state-schema.md
```

Expected: 150 行前後。

```bash
ls /Users/nishikataseiichi/.dotfiles/claude/skills/handover/references/
```

Expected: `project-state-schema.md` が存在する。

- [ ] **Step 4: SKILL.md の description を更新する（Edit）**

`old_string`:
```
---
name: handover
description: 現在のセッション内容を振り返り、project-state.json と handover.md を生成する
user-invocable: true
---
```

`new_string`:
```
---
name: handover
description: >-
  現在のセッションで行った作業・決定事項・アーキテクチャ変更を project-state.json に記録し、
  handover.md を生成する。コンテキスト圧縮の直前、/handover の明示呼び出し、
  ツール呼び出し累計 50 回超過時、または応答が遅延した時に使用する。
user-invocable: true
---
```

- [ ] **Step 5: SKILL.md の JSON スキーマブロックを参照文に置換する（Edit）**

`old_string` は現 SKILL.md の手順 2（`2. このセッションの作業内容を以下の JSON スキーマに従って整理する:`）の直前から、手順 4（マージルール）の末尾 (`- \`session\`: 新しい値で上書き`) までの範囲。

具体的には以下のブロック全体を `old_string` に指定する:

```
2. このセッションの作業内容を以下の JSON スキーマに従って整理する:

```json
{
  "version": 5,
  "generated_at": "ISO8601 現在時刻",
  ... (90 行の JSON)
}
```

3. status の自動判定:
   - active_tasks の全タスクが `done` → status を `ALL_COMPLETE` に設定
   - それ以外 → `READY`

4. 既存の project-state.json とのマージルール:
   - active_tasks: 同じ ID のタスクは上書き、新しいタスクは追加
   ... (14 行のマージルール)
   - `session`: 新しい値で上書き

5. `{保存先}/project-state.json` に書き出す
```

`new_string`:
```
2. このセッションの作業内容を JSON スキーマに従って整理する。
   project-state.json の完全な JSON スキーマ、status 自動判定ルール、既存 state とのマージルールは
   [references/project-state-schema.md](references/project-state-schema.md) を参照する。

3. `{保存先}/project-state.json` に書き出す
```

**実装時の注意:** 実際の Edit 呼び出し時は、SKILL.md の該当ブロックを Read で正確な文字列を取得してから old_string に指定する。上記は意図の説明であり、逐語ではない。

- [ ] **Step 6: SKILL.md の Phase Summary YAML と handover.md 出力フォーマットを参照文に置換する（Edit）**

Phase Summary 生成セクションの YAML ブロックと、handover.md 出力フォーマットのブロックを削除し、参照文に置換する。

`old_string` は「Phase Summary 生成（pipeline ワークフロー時）」セクションの YAML ブロック部分:

```
3. Phase Summary フォーマット:

```yaml
phase: N
... (約 25 行の YAML)
regate_history: []
```

4. `project-state.json` に `phase_summaries` マッピングを追加
```

`new_string`:
```
3. Phase Summary フォーマットは [references/project-state-schema.md](references/project-state-schema.md) を参照する。

4. `project-state.json` に `phase_summaries` マッピングを追加
```

続いて handover.md 出力フォーマットの置換。`old_string`:
```
6. `{保存先}/handover.md` を以下のフォーマットで自動生成する:

```
# Session Handover
... (約 45 行の出力テンプレート)
## Known Issues
- [severity] 問題の説明（なければ「なし」）
```
```

`new_string`:
```
6. `{保存先}/handover.md` を自動生成する。
   出力フォーマットは [references/project-state-schema.md](references/project-state-schema.md) を参照する。
```

**実装時の注意:** Step 5 と同じく、Read で取得した逐語を old_string に使用する。

- [ ] **Step 7: SKILL.md の短縮を検証する**

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/handover/SKILL.md
```

Expected: 200 行前後（元 305 行から約 100 行減）。500 行以下であることを必ず確認。

```bash
head -10 /Users/nishikataseiichi/.dotfiles/claude/skills/handover/SKILL.md
```

Expected: frontmatter の `description: >-` の複数行ブロックが見える。

参照先ファイルへのリンクが SKILL.md 本文に存在することを確認:
```bash
grep -c "references/project-state-schema.md" /Users/nishikataseiichi/.dotfiles/claude/skills/handover/SKILL.md
```

Expected: 3 以上（description, JSON スキーマ位置, Phase Summary 位置, handover.md 位置）。

- [ ] **Step 8: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles && git add claude/skills/handover/SKILL.md claude/skills/handover/references/project-state-schema.md && git commit -m "$(cat <<'EOF'
chore(skills): externalize handover schema to references/

handover の SKILL.md に 90 行インラインされていた project-state.json の JSON スキーマ、
マージルール、Phase Summary YAML フォーマット、handover.md 出力フォーマットを
references/project-state-schema.md に分離。Progressive disclosure パターンに準拠。

description にも When (コンテキスト圧縮直前、明示呼び出し、ツール呼び出し 50 回超過、
応答遅延) を明示した。
EOF
)"
```

---

## Task 3: continue の description 更新

**Files:**
- Modify: `claude/skills/continue/SKILL.md:1-6`

- [ ] **Step 1: 現状の frontmatter を確認する**

```bash
head -6 /Users/nishikataseiichi/.dotfiles/claude/skills/continue/SKILL.md
```

Expected:
```
---
name: continue
description: handover.md から未完了タスクを確認し、承認後に作業を再開する
user-invocable: true
---
```

- [ ] **Step 2: description を更新する（Edit）**

`old_string`:
```
---
name: continue
description: handover.md から未完了タスクを確認し、承認後に作業を再開する
user-invocable: true
---
```

`new_string`:
```
---
name: continue
description: >-
  前セッションの project-state.json から未完了タスク（in_progress/blocked）を特定し、
  ユーザー承認後に作業を再開する。/continue の明示呼び出し、"continue from handover"
  のような継続指示、handover.md への言及を検出した時に使用する。worktree 切り替えと
  Pipeline Detection も含む。
user-invocable: true
---
```

- [ ] **Step 3: 更新を検証する**

```bash
head -10 /Users/nishikataseiichi/.dotfiles/claude/skills/continue/SKILL.md
```

Expected: `description: >-` の複数行ブロックが見える、`name: continue` と `user-invocable: true` が保持されている。

```bash
awk '/^description:/,/^user-invocable:/' /Users/nishikataseiichi/.dotfiles/claude/skills/continue/SKILL.md | wc -c
```

Expected: 300 文字程度（1024 文字制限内）。

- [ ] **Step 4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles && git add claude/skills/continue/SKILL.md && git commit -m "$(cat <<'EOF'
chore(skills): clarify when-to-use in continue description

continue スキルの description が when to use を欠いていたため追記。
/continue の明示呼び出し、継続指示、handover.md 参照を発見時に起動する旨を明示。
EOF
)"
```

---

## Task 4: linear-refresh の description 更新

**Files:**
- Modify: `claude/skills/linear-refresh/SKILL.md:1-8`

- [ ] **Step 1: 現状の frontmatter を確認する**

```bash
head -8 /Users/nishikataseiichi/.dotfiles/claude/skills/linear-refresh/SKILL.md
```

Expected: `description:` に「Linearチームのチケット棚卸し...実行するスキル」が含まれる。`argument-hint:` が保持されている。

- [ ] **Step 2: description を更新する（Edit）**

`old_string`:
```
---
name: linear-refresh
description: >-
  Linearチームのチケット棚卸し・構造整理・新規検出を一気通貫で実行するスキル。
  チケットに紐付いた外部リンクの探索に加え、キーワード検索とチケット逆引きで
  未紐付きの外部ソースも発見する。
argument-hint: "[--force] [--skip-discovery] [--cleanup-only] [--add-only]"
---
```

`new_string`:
```
---
name: linear-refresh
description: >-
  Linear チケットの棚卸し・構造整理・未登録ソース発見を
  Collect/Discover/Analyze/Approve/Execute の 5 ステップで一気通貫実行する。
  既存の外部リンク探索に加え、Slack/GitHub のキーワード検索と逆引きで未紐付きの
  外部ソースも発見する。定期的な Linear メンテナンス、または「棚卸し」「リフレッシュ」
  「整理」の依頼時に使用する。
argument-hint: "[--force] [--skip-discovery] [--cleanup-only] [--add-only]"
---
```

- [ ] **Step 3: 更新を検証する**

```bash
head -10 /Users/nishikataseiichi/.dotfiles/claude/skills/linear-refresh/SKILL.md
```

Expected: `description:` に「5 ステップ」「Slack/GitHub」「棚卸し」「リフレッシュ」「整理」が含まれる。`argument-hint:` が保持されている。

自己参照語が除去されたことを確認:
```bash
awk '/^description:/,/^argument-hint:/' /Users/nishikataseiichi/.dotfiles/claude/skills/linear-refresh/SKILL.md | grep -c "スキル"
```

Expected: `0`（description に `スキル` という自己参照語が無い）。

- [ ] **Step 4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles && git add claude/skills/linear-refresh/SKILL.md && git commit -m "$(cat <<'EOF'
chore(skills): refine linear-refresh description with steps and triggers

linear-refresh の description を以下の観点で調整:
- 自己参照語「スキル」を削除
- 5 ステップ (Collect/Discover/Analyze/Approve/Execute) を明示
- When to use（定期メンテナンス、「棚卸し」等の依頼時）を追加
EOF
)"
```

---

## Task 5: slackcli の metadata ブロック削除

**Files:**
- Modify: `claude/skills/slackcli/SKILL.md:1-12`

- [ ] **Step 1: 現状の frontmatter を確認する**

```bash
head -12 /Users/nishikataseiichi/.dotfiles/claude/skills/slackcli/SKILL.md
```

Expected: `metadata:` ブロック（version, openclaw.category, requires, cliHelp）が存在する。

- [ ] **Step 2: metadata ブロックを削除する（Edit）**

`old_string`:
```
---
name: slackcli
description: "Slack CLI: Send messages, read conversations, search, and manage Slack workspaces from the terminal. Use when the user asks anything related to Slack — sending messages, checking unreads, searching conversations, or managing workspaces. Also trigger when a Slack URL is provided (e.g., https://*.slack.com/archives/*, app.slack.com/*) or when the conversation context mentions Slack threads, channels, or messages."
metadata:
  version: 0.3.1
  openclaw:
    category: "productivity"
    requires:
      bins:
        - slackcli
    cliHelp: "slackcli --help"
---
```

`new_string`:
```
---
name: slackcli
description: "Slack CLI: Send messages, read conversations, search, and manage Slack workspaces from the terminal. Use when the user asks anything related to Slack — sending messages, checking unreads, searching conversations, or managing workspaces. Also trigger when a Slack URL is provided (e.g., https://*.slack.com/archives/*, app.slack.com/*) or when the conversation context mentions Slack threads, channels, or messages."
---
```

- [ ] **Step 3: metadata 削除を検証する**

```bash
head -5 /Users/nishikataseiichi/.dotfiles/claude/skills/slackcli/SKILL.md
```

Expected: `---`, `name: slackcli`, `description: "..."`, `---` で frontmatter が完結している。

```bash
grep -c "^metadata:" /Users/nishikataseiichi/.dotfiles/claude/skills/slackcli/SKILL.md
```

Expected: `0`（`metadata:` キーが残っていない）。

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/slackcli/SKILL.md
```

Expected: 120 行前後（元 128 行から約 8 行減）。

- [ ] **Step 4: Commit**

```bash
cd /Users/nishikataseiichi/.dotfiles && git add claude/skills/slackcli/SKILL.md && git commit -m "$(cat <<'EOF'
chore(skills): remove non-standard metadata block from slackcli

slackcli の frontmatter に openclaw 独自拡張の metadata ブロック (version,
openclaw.category, requires, cliHelp) が含まれていたが、Anthropic の Skill
仕様では name と description のみが公式。バージョンや CLI 要件は本文の
Prerequisites セクションで既に言及されているため情報損失なし。
EOF
)"
```

---

## Task 6: 最終検証

**Files:**
- Read-only: 全 SKILL.md

- [ ] **Step 1: 全 SKILL.md に frontmatter が存在することを確認する**

```bash
for f in /Users/nishikataseiichi/.dotfiles/claude/skills/*/SKILL.md; do
  first_line=$(head -1 "$f")
  if [ "$first_line" != "---" ]; then
    echo "MISSING FRONTMATTER: $f"
  fi
done
echo "---DONE---"
```

Expected: `MISSING FRONTMATTER` の出力が 1 件も無く、`---DONE---` のみが表示される。

- [ ] **Step 2: 全 SKILL.md の行数が 500 以下であることを確認する**

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/*/SKILL.md | awk 'NR<=8 { if ($1 > 500) print "OVER 500 LINES:", $2, "=", $1 } END { print "---DONE---" }'
```

Expected: `OVER 500 LINES` の出力が無く、`---DONE---` のみが表示される。

- [ ] **Step 3: 各 SKILL.md の name 値がディレクトリ名と一致することを確認する**

```bash
for f in /Users/nishikataseiichi/.dotfiles/claude/skills/*/SKILL.md; do
  dir=$(basename "$(dirname "$f")")
  name=$(awk -F': ' '/^name:/ { print $2; exit }' "$f")
  if [ "$dir" != "$name" ]; then
    echo "NAME MISMATCH: dir=$dir name=$name path=$f"
  fi
done
echo "---DONE---"
```

Expected: `NAME MISMATCH` の出力が無く、`---DONE---` のみが表示される。

- [ ] **Step 4: description に XML タグが含まれないことを確認する**

```bash
for f in /Users/nishikataseiichi/.dotfiles/claude/skills/*/SKILL.md; do
  desc=$(awk '/^description:/,/^[a-z-]+:|^---$/' "$f" | head -20)
  if echo "$desc" | grep -qE '<[a-zA-Z/][^>]*>'; then
    echo "XML TAG FOUND in description: $f"
  fi
done
echo "---DONE---"
```

Expected: `XML TAG FOUND` の出力が無く、`---DONE---` のみが表示される。

- [ ] **Step 5: handover の references リンクが解決することを確認する**

```bash
ls /Users/nishikataseiichi/.dotfiles/claude/skills/handover/references/project-state-schema.md && echo "REFERENCE EXISTS"
```

Expected: `REFERENCE EXISTS` が表示される。

```bash
grep -c "references/project-state-schema.md" /Users/nishikataseiichi/.dotfiles/claude/skills/handover/SKILL.md
```

Expected: `3` 以上。

- [ ] **Step 6: doc-audit の frontmatter 内容を目視確認する**

```bash
head -10 /Users/nishikataseiichi/.dotfiles/claude/skills/doc-audit/SKILL.md
```

Expected: `name: doc-audit` と `description: >-` の複数行ブロックが見える。description の中に `md ドキュメント`, `4 Layer`, `/doc-audit` の key terms が含まれる。

- [ ] **Step 7: slackcli に metadata ブロックが残っていないことを確認する**

```bash
grep -c "^metadata:\|^  openclaw:" /Users/nishikataseiichi/.dotfiles/claude/skills/slackcli/SKILL.md
```

Expected: `0`。

- [ ] **Step 8: ベースライン比較**

```bash
wc -l /Users/nishikataseiichi/.dotfiles/claude/skills/*/SKILL.md
```

Expected: `handover` が 215 行前後に減少、`slackcli` が 120 行前後に減少、`doc-audit` が 114 行前後に増加、合計が 1,370 行前後。

- [ ] **Step 9: 最終検証コミット（変更が無ければスキップ）**

検証のみで変更が無い場合は commit 不要。もし検証中に修正が必要になった場合は:

```bash
cd /Users/nishikataseiichi/.dotfiles && git status
```

で差分を確認し、適切な commit にまとめる。

---

## Self-Review Checklist

実装完了後、以下を確認する:

- [ ] spec の Critical 項目（doc-audit frontmatter）が Task 1 で対応された
- [ ] spec の Medium 項目（handover JSON スキーマ外出し、handover description、continue description）が Task 2, 3 で対応された
- [ ] spec の Minor 項目（linear-refresh description、slackcli metadata 削除）が Task 4, 5 で対応された
- [ ] spec の「変更しない項目」（continue の name、triage/doc-check/weekly-sync の frontmatter 等）に手を入れていない
- [ ] 全タスクで commit が行われている（atomic commits）
- [ ] references/project-state-schema.md が handover ディレクトリ内に作成されている
- [ ] 最終検証 (Task 6) の全ステップが PASS している

## 想定完了状態

- commit 数: 5（Task 1-5 各 1）、Task 6 は検証のみ
- 新規ファイル: 1（handover/references/project-state-schema.md）
- 変更ファイル: 5（doc-audit, handover, continue, linear-refresh, slackcli）
- SKILL.md 合計行数: 1,458 → 約 1,370（handover が 90 行減、slackcli が 8 行減、doc-audit が 7 行増、他 description 調整で微増減）
