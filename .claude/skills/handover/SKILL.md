---
name: handover
description: 現在のセッション内容を振り返り、project-state.json と handover.md を生成する
user-invocable: true
---

このセッションで行った作業を振り返り、`.claude/project-state.json` を生成（既存があればマージ）し、`.claude/handover.md` を自動生成する。

## 手順

1. `.claude/project-state.json` が既に存在するか確認する
   - 存在する場合 → 既存の内容を読み込み、マージベースで更新する
   - 存在しない場合 → 新規作成する

2. このセッションの作業内容を以下の JSON スキーマに従って整理する:

```json
{
  "version": 2,
  "generated_at": "ISO8601 現在時刻",
  "session_id": "現在のセッションID（不明なら unknown）",
  "status": "READY | ALL_COMPLETE",
  "active_tasks": [
    {
      "id": "T1",
      "description": "タスクの説明",
      "status": "done | in_progress | blocked",
      "commit_sha": "コミットした場合のSHA（done の場合のみ）",
      "file_paths": ["関連ファイルパス"],
      "next_action": "次にやるべき具体的なアクション（in_progress/blocked の場合）",
      "blockers": ["ブロッカーの説明（blocked の場合）"],
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
  "session_hash": ""
}
```

3. status の自動判定:
   - active_tasks の全タスクが `done` → status を `ALL_COMPLETE` に設定
   - それ以外 → `READY`

4. 既存の project-state.json とのマージルール:
   - active_tasks: 同じ ID のタスクは上書き、新しいタスクは追加
   - recent_decisions: 追記（重複しない）
   - architecture_changes: 追記（直近10件を保持、古い順に削除）
   - known_issues: 解決済みなら削除、新規は追加

5. `.claude/project-state.json` に書き出す

6. `.claude/handover.md` を以下のフォーマットで自動生成する:

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
  （blocked の場合）
  - blocker: ブロッカー

## Blockers
- ブロッカーの一覧（なければ「なし」）

## Context
- recent_decisions の内容

## Architecture Changes (Recent)
- commit_sha: 要約

## Known Issues
- [severity] 問題の説明（なければ「なし」）
```

## 制約

- 200行以内
- コードブロックは含めず、ファイルパス:行番号で参照
- このセッションで実際に行った事実のみ記述し、推測や補足は含めない
- 日本語で出力
- `.claude/` ディレクトリが存在しない場合は作成すること
