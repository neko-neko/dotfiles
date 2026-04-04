---
name: phase-summary
description: >-
  Phase Summary の生成フォーマットとアーティファクト追跡ルール。
  各フェーズ完了時に構造化サマリーを生成し保存する。
---

# Phase Summary 生成プロトコル

各フェーズ完了時にオーケストレーターが生成する構造化サマリー。

## 保存先

`.claude/handover/{branch}/{fingerprint}/phase-summaries/{phase_id}.yml`

## フォーマット

```yaml
phase_id: <phase_id>
phase_name: <name>
status: completed | failed
timestamp: <ISO8601>
attempt: <N>
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

# execute フェーズ専用。status: in_progress の場合のみ有効。
# mid-phase handover 時のサブステップ復帰に使用する。
inner_loop_state:
  current_substep: Impl | TestEnrich | Verify | null
  impl_progress:
    completed_tasks: []
    remaining_tasks: []
    last_commit: <sha>
  loop_iteration: 0
  failure_history: []

# Audit Gate が validation チェックを実行した結果。
# 後続フェーズの auditor が「上流で何が検証済みか」を把握するために使用する。
validation_record:
  - criterion: <question>
    verdict: PASS | FAIL
    evidence: <根拠の要約>

regate_history: []
```

## アーティファクト型

| type | 解決方法 | 用途 |
|------|---------|------|
| `file` | Read で読み込み | 設計書、計画書、レポート |
| `git_range` | git diff で参照 | コード変更 |
| `inline` | そのまま使用 | 短いテスト結果、メトリクス |

## concerns/directives 伝播ルール

- 各フェーズは concerns と directives を emit できる
- 両者は `target_phase` で送信先を指定
- エンジンは受信フェーズ進入時に `target_phase` でフィルタし注入する

## inner_loop_state

execute フェーズ専用。Inner Loop の進捗状態を記録する。

- `current_substep`: 現在のサブステップ（Impl / TestEnrich / Verify）。null は未開始。
- `impl_progress.completed_tasks`: 完了済みタスク番号のリスト（implementation_plan のタスク番号に対応）。
- `impl_progress.remaining_tasks`: 未完了タスク番号のリスト。
- `impl_progress.last_commit`: 最後にコミットされた SHA。
- `loop_iteration`: Failure Router のループ回数（0 = 初回）。
- `failure_history`: 過去のループでの失敗情報。Failure Router の判定に使用。

resume 時、engine は inner_loop_state を検出し、current_substep から再開する。

## validation_record

Audit Gate が contract.validation + additional の各 question に対して実行した判定結果。

- `criterion`: 検証した question（pipeline.yml contract.validation または done-criteria additional から）。
- `verdict`: PASS または FAIL。
- `evidence`: 判定の根拠の要約（1-2文）。

後続フェーズの auditor は、上流の validation_record を参照することで「この artifact は上流で何が検証済みか」を把握し、フェーズ間の意味的一貫性を判断できる。
