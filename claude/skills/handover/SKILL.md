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
  "version": 3,
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

5. `{保存先}/project-state.json` に書き出す

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
