# Autonomy Gates

各フェーズの自律動作レベルと GATE 判定ルール。
フェーズ番号は Phase Map（audit-gate-protocol.md）を参照。

## Gate Decision Table

### {design} (feature-dev) / {rca} (debug-flow)

| Situation | Action | Rationale |
|-----------|--------|-----------|
| brainstorming が設計質問を提示 | PAUSE | ユーザーの意思決定が必要。自動回答禁止 |
| ユーザーが回答を提供 | AUTO | 次の質問 or 設計書ドラフトへ進む |
| 設計書ドラフト完成 | AUTO | worktree 作成を実行 |
| worktree テスト通過 | AUTO | 設計書を worktree 内にコミット |
| worktree テスト失敗 | PAUSE | 続行 or STOP をユーザーに提案 |
| 設計書が worktree 内にコミット済み | AUTO | 次フェーズへ自動遷移 |
| ユーザーが中断を指示 | STOP | クリーンアップ不要で終了 |

### {spec-review} / {fix-plan-review}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| エージェントエラー | AUTO | 該当エージェントをスキップし残りで続行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 全観点パス | AUTO | handover 実行後に次フェーズへ自動遷移 |
| 3回レビュー不合格 | PAUSE | 設計の根本的見直しを提案 |

### {plan} / {fix-plan}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| writing-plans 起動 | AUTO | 計画書作成を自動実行 |
| 計画書がコミット済み | AUTO | 次フェーズへ自動遷移 |
| writing-plans 失敗 | PAUSE | 失敗内容を報告しユーザー判断を仰ぐ |

### {plan-review} / {fix-plan-review}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| エージェントエラー | AUTO | 該当エージェントをスキップし残りで続行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 全観点パス | AUTO | handover 実行後に {execute} へ自動遷移 |
| 3回レビュー不合格 | PAUSE | 計画の根本的見直しを提案 |

### {execute}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| サブエージェントによるタスク実行 | AUTO | 計画書に基づき自動実行 |
| 個別タスク完了 | AUTO | 次のタスクへ進む |
| 全タスク完了 | AUTO | {smoke-test}/{doc-audit} へ自動遷移 |
| タスク失敗（1-2回目） | AUTO | リトライ |
| タスク失敗（3回目） | PAUSE | 設計ギャップをエスカレーション |

### {smoke-test}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| `--smoke` 未指定かつ UI 関連なし | AUTO | {smoke-test} をスキップして {doc-audit} へ |
| UI 関連キーワード検出 | PAUSE | 自動有効化をユーザーに提案 |
| smoke-test 起動 | AUTO | 4ステップを自動実行 |
| サーバー起動不可 | PAUSE | ユーザーに起動コマンドを確認 |
| VRT 差分検出 | PAUSE | ベースライン更新をユーザーに確認 |
| 全ステップ PASS | AUTO | {doc-audit} へ自動遷移 |
| FAIL（修正可能） | AUTO | 自動修正 → 再実行（最大2回） |
| FAIL（修正不能） | PAUSE | ユーザーに報告して判断を委ねる |
| フレーキーテスト検出 | AUTO | 報告のみでブロックしない。{doc-audit} へ |

### {doc-audit}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| `--doc` 未指定 | AUTO | {doc-audit} をスキップして {review} へ |
| doc-audit 起動 | AUTO | 4 Layer 監査を自動実行 |
| 修正完了 | AUTO | {review} へ自動遷移 |
| 修正不能 | PAUSE | ユーザーに報告して判断を委ねる |

### {review}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| レビューエージェント起動 | AUTO | 並列レビューを自動実行 |
| レポート生成完了 | PAUSE | ユーザーに findings を提示し修正選択を待つ |
| ユーザーが修正を選択 | AUTO | 選択された findings を修正 |
| 修正後テスト通過 | AUTO | handover 実行後に {integrate} へ自動遷移 |
| 修正後テスト失敗（1-2回目） | AUTO | リトライ |
| 修正後テスト失敗（3回目） | PAUSE | 手動対応が必要 |
| `--e2e` 指定時: テストレビュー起動 | AUTO | 並列レビューを自動実行 |
| `--e2e` 指定時: レポート生成完了 | PAUSE | ユーザーに findings を提示 |
| テスト追加後の既存テスト破損 | PAUSE | 影響範囲を報告 |

### {integrate}

| Situation | Action | Rationale |
|-----------|--------|-----------|
| 統合方法の選択肢提示 | PAUSE | wt merge / PR / ブランチ保持 / 破棄はユーザーが選択する |
| ユーザーが wt merge を選択 | AUTO | worktrunk スキルを invoke し `wt merge` を実行 |
| ユーザーが PR を選択 | AUTO | `git push -u` + `gh pr create` → `wt remove` |
| ユーザーがブランチ保持を選択 | AUTO | 何もしない |
| ユーザーが破棄を選択 | AUTO | `wt remove` を実行 |
| マージコンフリクト | PAUSE | コンフリクトを報告し手動解決を提案 |
| 統合完了 | AUTO | パイプライン完了 |

### 全フェーズ共通

| Situation | Action | Rationale |
|-----------|--------|-----------|
| Context 逼迫 | PAUSE | `/handover` を実行してパイプライン状態を保存 |
| `--codex` 指定時に Codex 接続失敗 | AUTO | 警告し codex なしで続行 |

### Audit Gate

| Situation | Action | Rationale |
|-----------|--------|-----------|
| Audit Gate: verdict PASS | AUTO | 全 blocker 基準 PASS。quality_warnings をユーザーに提示し次フェーズへ |
| Audit Gate: verdict FAIL, attempt < max_retries | AUTO | Fix Dispatch → 再監査のループを自動実行 |
| Audit Gate: verdict FAIL, attempt >= max_retries | PAUSE | 累積診断レポートを提示しユーザー判断を委任 |
| Audit Gate: escalation != null | PAUSE | 前フェーズの成果物に根本原因。残 attempt に関わらず即 PAUSE |
| Audit Gate: fix_status blocked | PAUSE | 修正不能。即 PAUSE |
| Audit Gate: Agent output invalid (2回目) | PAUSE | Audit Agent の出力が不正。手動確認を依頼 |
| Re-gate: {execute} PASS + {smoke-test} PASS | AUTO | Re-review を実行 |
| Re-gate: re-review で findings なし | AUTO | {review} Audit Gate へ |
| Re-gate: re-review が3回連続 findings | PAUSE | 根本的な設計見直しを促す |

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
