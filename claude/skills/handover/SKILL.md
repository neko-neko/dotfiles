---
name: handover
description: >-
  現在のセッションで行った作業・決定事項・アーキテクチャ変更を project-state.json に記録し、
  handover.md を生成する。コンテキスト圧縮の直前、/handover の明示呼び出し、
  ツール呼び出し累計 50 回超過時、または応答が遅延した時に使用する。
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
3. **チーム所属あり** → `.agents/handover/{team-name}/{agent-name}/`（以降のブランチ分離は適用しない）

### 単体セッション（チーム所属なし）

1. ルートディレクトリの決定:
   - `git rev-parse --show-toplevel` でリポジトリルートを取得
   - `git worktree list --porcelain` で worktree 一覧を取得し、現在のブランチに対応する worktree パスがあるか確認
   - CWD のリポジトリルートと異なる worktree が検出された場合、`AskUserQuestion` でユーザーに保存先を確認する:
     > worktree `{path}` が検出されました。こちらの `.agents/` に保存しますか？
2. ブランチ名を `git rev-parse --abbrev-ref HEAD` で取得。detached HEAD の場合は `detached-{sha7}` を使用
3. `{root}/.agents/handover/{branch}/` 配下を走査:
   - status が `READY` のセッション（= `in_progress` / `blocked` タスクを持つ）があれば、その fingerprint を再利用
   - なければ新しい fingerprint（`$(date +%Y%m%d-%H%M%S)`）を生成
4. 保存先: `{root}/.agents/handover/{branch}/{fingerprint}/`
5. 保存先ディレクトリが存在しない場合は `mkdir -p` で作成する

## 手順

1. `{保存先}/project-state.json` が既に存在するか確認する
   - 存在する場合 → 既存の内容を読み込み、マージベースで更新する
   - 存在しない場合 → 新規作成する

2. このセッションの作業内容を JSON スキーマに従って整理する。
   project-state.json の完全な JSON スキーマ、status 自動判定ルール、既存 state とのマージルールは
   [references/project-state-schema.md](references/project-state-schema.md) を参照する。

3. `{保存先}/project-state.json` に書き出す

### Linear Sync（オプション）

project-state.json 生成後、`linear.issue_id` フィールドが設定されている場合:

1. `claude/skills/linear-sync/SKILL.md` の `sync_handover` セクションを Read
2. セクションの手順に従い、project-state.json のアップロードと中断コメントの投稿を実行
3. API 失敗時はワークフローをブロックせず、warning を出力して続行

## Phase Summary 生成（pipeline ワークフロー時）

`project-state.json` の `pipeline` フィールドが存在する場合（feature-dev / debug-flow）:

1. `.agents/handover/{branch}/{fingerprint}/phase-summaries/` ディレクトリを作成
2. 完了済みフェーズの Phase Summary を生成（未生成分のみ）
3. Phase Summary フォーマットは [references/project-state-schema.md](references/project-state-schema.md) を参照する。

4. `project-state.json` に `phase_summaries` マッピングを追加
5. `session` フィールドを生成:
   - `session_id`: `${CLAUDE_SESSION_ID}`
   - `resume_hint`: current_phase の概要と前フェーズからの concerns/directives

6. `{保存先}/handover.md` を自動生成する。
   出力フォーマットは [references/project-state-schema.md](references/project-state-schema.md) を参照する。

## Cleanup

handover 実行時に、`{root}/.agents/handover/` 配下の `ALL_COMPLETE` かつ `generated_at` が7日以上前のセッションディレクトリを自動削除する。削除前にログ出力する。

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
- `.agents/` ディレクトリが存在しない場合は作成すること

## Handover Protocol

- `continue from handover` や handover.md への言及があった場合、まず前回の変更がコミット済みか `git log` で確認してから作業を開始すること
- 全タスク完了済み（status: ALL_COMPLETE）なら即座にその旨を報告し、コードベースの探索を始めないこと
- handover 文書には必ず以下を含めること:
  - 具体的なファイルパス
  - タスクID（T1, T2, ...）
  - ブロッカー（あれば）
  - コミット SHA（完了タスク）
- handover.md は project-state.json から自動生成されたビューであり、直接編集しないこと

