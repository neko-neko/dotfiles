# コミュニケーション方針

 - 技術的に誤った意見には根拠を示して反論すること。懸念・代替案は実装提案の前に伝える
 - 曖昧な指示に対しては推測で進めず、具体的に確認すること

## 出力方針

 - 設計・レビュー・分析は分割確認せず、完全な形で一度に出力すること

## 実装規律

 - 初回の実装パスでバリデーション（範囲制約、境界値、型チェック）を含めること
 - コミット前に linter・型チェッカー・フォーマッター・テストを実行すること

## Git Workflow

 - git worktree 使用時は、ファイル編集前に作業ディレクトリが worktree パスであることを確認すること

## マルチエージェント

 - サブエージェントには明確なスコープと完了条件を与え、作業の重複を防ぐこと
 - サブエージェントの出力は検証すること

## Intent Guard

 - スキル呼び出し時は、そのスキルのみ実行する。別スキルへの暗黙的なピボットは禁止。切り替えが必要な場合はユーザーに承認を求めること
 - サブエージェント生成時、model パラメータはユーザーが明示的に指定した場合のみ設定する。指定がなければ省略（親モデルを継承）すること
 - 3ステップ以上のマルチステップ作業は、計画（brainstorming / writing-plans / EnterPlanMode のいずれか）を経てから実行すること。計画フェーズのスキップ禁止

## セッション管理

 - 完了タスクの要約・整理はユーザーに指摘される前に行うこと
 - セッション開始時に `.claude/handover/` 配下に READY ステータスのセッションが存在する場合は確認すること（パス解決は下記参照）

## Handover Protocol

- `continue from handover` や handover.md への言及があった場合、まず前回の変更がコミット済みか `git log` で確認してから作業を開始すること
- 全タスク完了済み（status: ALL_COMPLETE）なら即座にその旨を報告し、コードベースの探索を始めないこと
- handover 文書には必ず以下を含めること:
  - 具体的なファイルパス
  - タスクID（T1, T2, ...）
  - ブロッカー（あれば）
  - コミット SHA（完了タスク）
- handover.md は project-state.json から自動生成されたビューであり、直接編集しないこと

### パス解決

- **単体セッション**: `.claude/handover/{branch}/{session-fingerprint}/` 配下の project-state.json と handover.md
- **マルチエージェント（チーム所属時）**: `.claude/handover/{team-name}/{agent-name}/` 配下の project-state.json と handover.md（既存と同じ）
- セッション開始時は `.claude/handover/` を走査し、READY ステータスの project-state.json を読み込むこと
- worktree 環境では CWD 以外の worktree の `.claude/handover/` も検索すること
- `.claude/project-state.json`（v2 形式）が残っている場合は新パスへマイグレーションすること

### マルチエージェント時の自律的 Handover

- チーム所属エージェントはコンテキスト圧縮通知・ツール呼び出し50回超過・応答速度低下のいずれかで自律的に handover を実行すること
- handover 後は Task tool で同じ type/name/team_name の後継エージェントを生成し、コンテキストを引き継ぐこと
- チーム終了時に `.claude/handover/{team-name}/` を削除してクリーンアップすること
