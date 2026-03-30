# Document Template: Workflow Report

Linear Document として作成・更新される Workflow Report の生成仕様。
`sync_workflow_start` で初期生成、`sync_phase` で毎回全体を再生成して上書き更新する。

## 生成ルール

1. 全セクションを毎回完全に再生成する（差分更新ではなく全体上書き）
2. まだ実行されていないフェーズは Status: Pending、Summary/Evidence: — とする
3. Evidence 列にはアップロード済みファイル名を記載（リンクではなくファイル名のみ）
4. Status アイコン: PASS → ✅, FAIL → ❌, Done → ✅, Skipped → ⏭️, In Progress → 🔄, Pending → ⏳

## 出力フォーマット

以下の構造で Markdown を生成する。{placeholder} は実際の値で置換する。

~~~
# Workflow Report — {ticket_id}

## Overview
| Field | Value |
|-------|-------|
| Pipeline | {pipeline_name} |
| Branch | {branch_name} |
| Started | {started_at (ISO8601)} |
| Current Phase | {current_phase_number} / {total_phases} ({current_phase_name}) |
| Status | {workflow_status: In Progress | Handover | Complete} |

## Phase Progress
| # | Phase | Status | Summary | Evidence |
|---|-------|--------|---------|----------|
| 1 | {phase_1_name} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| 2 | {phase_2_name} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| ... | ... | ... | ... | ... |

## Evidence Index
| Phase | File | Description |
|-------|------|-------------|
| {phase_number} | {filename} | {label / description} |
| ... | ... | ... |

（アップロード済みエビデンスがない場合はこのセクションを空テーブルにする）

## Blockers / Known Issues
- {blocker_description}

（ブロッカーがない場合は「（なし）」と記載）

## Session Notes
- [{category}] {content}

（ノートがない場合はこのセクションを省略）
~~~

## pipeline ごとのフェーズ一覧

### debug-flow (8 phases)
1. RCA
2. Fix Plan
3. Plan Review
4. Execute
5. Smoke Test
6. Code Review
7. Test Review
8. Integrate

### feature-dev (10 phases)
1. Design
2. Plan
3. Design Review
4. Execute
5. Smoke Test
6. Doc Audit
7. Code Review
8. Test Review
9. Integrate
10. (reserved)

フェーズ名はワークフローから渡される phase_name を使用する。
上記は参考情報としてのデフォルト値。
