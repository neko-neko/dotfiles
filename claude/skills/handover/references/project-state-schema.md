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
