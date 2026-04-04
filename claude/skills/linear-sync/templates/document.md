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
| Current Phase | {current_phase_id} ({completed_count} / {total_phases}) |
| Status | {workflow_status: In Progress | Handover | Complete} |

## Phase Progress
| Phase | Status | Summary | Evidence |
|-------|--------|---------|----------|
| {phase_id} | {status_icon} {status} | {summary} | {evidence_filenames or —} |
| ... | ... | ... | ... |

## Evidence Index
| Phase | File | Description |
|-------|------|-------------|
| {phase_id} | {filename} | {label / description} |
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
1. rca
2. fix-plan
3. fix-plan-review
4. execute
5. accept-test
6. doc-audit
7. review
8. integrate

### feature-dev (9 phases)
1. design
2. spec-review
3. plan
4. plan-review
5. execute
6. accept-test
7. doc-audit
8. review
9. integrate

フェーズ名はワークフローから渡される phase_name を使用する。
上記は参考情報としてのデフォルト値。
