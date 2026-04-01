---
name: handover
description: 現在のセッション内容を振り返り、project-state.json と handover.md を生成する
user-invocable: true
---

このセッションで行った作業を振り返り、`project-state.json` を生成（既存があればマージ）し、`handover.md` を自動生成する。

## パス解決（保存先の決定）

以下の順序で保存先ディレクトリを決定する:

### チーム所属判定（既存と同じ）

1. 自分がチームに所属しているか確認する:
   - 自分を起動した prompt に `team_name` が指定されているか（最優先）
   - または、`~/.claude/teams/{team-name}/config.json` の `members` 配列に自分の `name` が含まれるか
2. エージェント名を取得する:
   - Task tool で起動された場合は `name` パラメータの値
   - 不明な場合は `default`
3. **チーム所属あり** → `.claude/handover/{team-name}/{agent-name}/`（以降のブランチ分離は適用しない）

### 単体セッション（チーム所属なし）

1. ルートディレクトリの決定:
   - `git rev-parse --show-toplevel` でリポジトリルートを取得
   - `git worktree list --porcelain` で worktree 一覧を取得し、現在のブランチに対応する worktree パスがあるか確認
   - CWD のリポジトリルートと異なる worktree が検出された場合、`AskUserQuestion` でユーザーに保存先を確認する:
     > worktree `{path}` が検出されました。こちらの `.claude/` に保存しますか？
2. ブランチ名を `git rev-parse --abbrev-ref HEAD` で取得。detached HEAD の場合は `detached-{sha7}` を使用
3. `{root}/.claude/handover/{branch}/` 配下を走査:
   - status が `READY` のセッション（= `in_progress` / `blocked` タスクを持つ）があれば、その fingerprint を再利用
   - なければ新しい fingerprint（`$(date +%Y%m%d-%H%M%S)`）を生成
4. 保存先: `{root}/.claude/handover/{branch}/{fingerprint}/`
5. 保存先ディレクトリが存在しない場合は `mkdir -p` で作成する

## 手順

1. `{保存先}/project-state.json` が既に存在するか確認する
   - 存在する場合 → 既存の内容を読み込み、マージベースで更新する
   - 存在しない場合 → 新規作成する

2. このセッションの作業内容を以下の JSON スキーマに従って整理する:

```json
{
  "version": 4,
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
      "phase": 5,
      "phase_name": "execute",
      "recorded_at": "ISO8601",
      "observations": [
        {
          "criteria_id": "D5-08",
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
      "relates_to_phase": 5
    }
  ],
  "session_hash": "",
  "linear_ticket_id": "Linear チケットID (例: ABC-123)。linear-sync supplement 使用時のみ設定。null または未設定の場合、sync は無効",
  "linear_document_id": "Linear Document ID。linear-sync supplement が作成した Workflow Report Document の ID。sync_workflow_start で設定される"
}
```

3. status の自動判定:
   - active_tasks の全タスクが `done` → status を `ALL_COMPLETE` に設定
   - それ以外 → `READY`

4. 既存の project-state.json とのマージルール:
   - active_tasks: 同じ ID のタスクは上書き、新しいタスクは追加
   - recent_decisions: 追記（重複しない）
   - architecture_changes: 追記（直近10件を保持、古い順に削除）
   - attempted_approaches: 同一タスク ID のタスクでは追記（重複排除、approach が同じエントリは上書き）
   - known_issues: 解決済みなら削除、新規は追加
   - phase_observations: 同一 phase のエントリは上書き、新規 phase は追加。各 phase の observations は最大5件（severity: warning > quality の順で保持）
   - session_notes: 追記（content 先頭50文字一致で重複排除）。セッションあたり最大10件
   - `linear_ticket_id`: 新しい値で上書き（通常は変わらないが、明示的変更時に対応）
   - `linear_document_id`: 新しい値で上書き

5. `{保存先}/project-state.json` に書き出す

### Linear Sync（オプション）

project-state.json 生成後、`linear_ticket_id` フィールドが設定されている場合:

1. `claude/skills/linear-sync/SKILL.md` の `sync_handover` セクションを Read
2. セクションの手順に従い、project-state.json のアップロードと中断コメントの投稿を実行
3. API 失敗時はワークフローをブロックせず、warning を出力して続行

6. `{保存先}/handover.md` を以下のフォーマットで自動生成する:

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
- [Phase N] criteria_id: observation（recommendation）

## Session Notes
- [category] content（Phase N）

## Known Issues
- [severity] 問題の説明（なければ「なし」）
```

## Cleanup

handover 実行時に、`{root}/.claude/handover/` 配下の `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。

## 自律的 Handover（マルチエージェント時）

チームに所属するエージェントは、以下の条件のいずれかに該当した場合、明示的な指示がなくても自律的にこの handover を実行すること:

- システムからコンテキスト圧縮の通知を受けた場合
- ツール呼び出し回数が累計 50 回を超えた場合
- 応答の生成が著しく遅くなったと判断した場合

「手遅れになる前に引き継ぐ」を原則とする。迷ったら handover する。

## 後継エージェントの生成（マルチエージェント時）

チームに所属するエージェントが自律的 handover を実行した場合、以下の手順で後継エージェントを生成する:

1. 上記の手順（project-state.json の書き出し、handover.md の生成）を完了する
2. Task tool で後継エージェントを生成する:
   - `subagent_type`: 自分と同じ type を指定
   - `name`: 自分と同じ name を指定
   - `team_name`: 自分と同じ team_name を指定
   - `prompt`: 以下のテンプレートを使用する

> あなたは {agent-name} の後継エージェントです。
> 前任のコンテキストを引き継いで作業を継続してください。
>
> 1. `{保存先}/project-state.json` を読み込む
> 2. 未完了タスク（in_progress / blocked）を確認する
> 3. 前任の next_action に従い作業を再開する
> 4. コンテキストが大きくなったら同様に handover すること（自律的 Handover の条件を参照）

3. 後継エージェントを生成したら、自分は作業結果を返して終了する

## 制約

- 200行以内
- コードブロックは含めず、ファイルパス:行番号で参照
- このセッションで実際に行った事実のみ記述し、推測や補足は含めない
- 設定されている言語で出力
- `.claude/` ディレクトリが存在しない場合は作成すること

## Handover Protocol

- `continue from handover` や handover.md への言及があった場合、まず前回の変更がコミット済みか `git log` で確認してから作業を開始すること
- 全タスク完了済み（status: ALL_COMPLETE）なら即座にその旨を報告し、コードベースの探索を始めないこと
- handover 文書には必ず以下を含めること:
  - 具体的なファイルパス
  - タスクID（T1, T2, ...）
  - ブロッカー（あれば）
  - コミット SHA（完了タスク）
- handover.md は project-state.json から自動生成されたビューであり、直接編集しないこと

