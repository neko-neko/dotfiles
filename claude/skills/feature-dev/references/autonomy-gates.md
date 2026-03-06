# Autonomy Gates -- /feature-dev

各フェーズの自律動作レベルと GATE 判定ルール。

## Gate Decision Table

### Phase 1: Design

| Situation | Action | Rationale |
|-----------|--------|-----------|
| brainstorming が設計質問を提示 | PAUSE | ユーザーの意思決定が必要。自動回答禁止 |
| ユーザーが回答を提供 | AUTO | 次の質問 or 設計書ドラフトへ進む |
| 設計書がコミット済み | AUTO | Phase 2 へ自動遷移 |
| ユーザーが中断を指示 | STOP | クリーンアップ不要で終了 |

### Phase 2: Spec Review

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| エージェントエラー | AUTO | 該当エージェントをスキップし残りで続行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 全観点パス | AUTO | handover 実行後に Phase 3 へ自動遷移 |
| 3回レビュー不合格 | PAUSE | 設計の根本的見直しを提案 |

### Phase 3: Plan

| Situation | Action | Rationale |
|-----------|--------|-----------|
| writing-plans 起動 | AUTO | 計画書作成を自動実行 |
| 計画書がコミット済み | AUTO | Phase 4 へ自動遷移 |
| writing-plans 失敗 | PAUSE | 失敗内容を報告しユーザー判断を仰ぐ |

### Phase 4: Plan Review

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| エージェントエラー | AUTO | 該当エージェントをスキップし残りで続行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 全観点パス | AUTO | handover 実行後に Phase 5 へ自動遷移 |
| 3回レビュー不合格 | PAUSE | 計画の根本的見直しを提案 |

### Phase 5: Workspace

| Situation | Action | Rationale |
|-----------|--------|-----------|
| worktree 作成 | AUTO | ブランチと worktree を自動作成 |
| テスト通過 | AUTO | Phase 6 へ自動遷移 |
| テスト失敗 | PAUSE | 続行 or STOP をユーザーに提案 |

### Phase 6: Execute

| Situation | Action | Rationale |
|-----------|--------|-----------|
| サブエージェントによるタスク実行 | AUTO | 計画書に基づき自動実行 |
| 個別タスク完了 | AUTO | 次のタスクへ進む |
| 全タスク完了 | AUTO | Phase 7 へ自動遷移 |
| タスク失敗（1-2回目） | AUTO | リトライ |
| タスク失敗（3回目） | PAUSE | 設計ギャップをエスカレーション |

### Phase 7: Code Review

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 修正後テスト通過 | AUTO | handover 実行後に Phase 8/9 へ自動遷移 |
| 修正後テスト失敗（1-2回目） | AUTO | リトライ |
| 修正後テスト失敗（3回目） | PAUSE | 手動対応が必要 |

### Phase 8: Test Review

| Situation | Action | Rationale |
|-----------|--------|-----------|
| `--e2e` 未指定 | AUTO | Phase 8 をスキップして Phase 9 へ |
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 修正完了・テスト通過 | AUTO | handover 実行後に Phase 9 へ自動遷移 |
| テスト追加後の既存テスト破損 | PAUSE | 影響範囲を報告 |

### Phase 9: Integrate

| Situation | Action | Rationale |
|-----------|--------|-----------|
| 統合方法の選択肢提示 | PAUSE | merge/PR/keep/discard はユーザーが選択する |
| ユーザーが選択 | AUTO | 選択に従い実行 |
| マージコンフリクト | PAUSE | コンフリクトを報告し手動解決を提案 |
| 統合完了 | AUTO | パイプライン完了 |

### 全フェーズ共通

| Situation | Action | Rationale |
|-----------|--------|-----------|
| Context 逼迫 | PAUSE | `/handover` を実行してパイプライン状態を保存 |
| `--codex` 指定時に codex 未インストール | AUTO | 警告し codex なしで続行 |

## Autonomy Mode 定義

| Mode | 説明 |
|------|------|
| INTERACTIVE | ユーザーとの対話が必要。判断ポイントで必ず PAUSE |
| AUTONOMOUS | 自動実行。失敗時のみ PAUSE |
| AUTONOMOUS+GATE | 自動実行だが、特定条件（テスト失敗、累積エラー）で PAUSE |

## 原則

- PAUSE はユーザーの意思決定を待つことを意味する
- AUTO は次のステップへ自動的に進むことを意味する
- STOP はパイプラインを終了することを意味する
- 判断に迷った場合は PAUSE を選択する
