---
name: linear-sync
description: >-
  ワークフロー（feature-dev/debug-flow）のフェーズ進捗・エビデンスを
  Linear チケットに自動同期する supplement skill。
  --linear フラグで有効化。ワークフローの Audit Gate 後に invoke される。
user-invocable: false
---

# linear-sync supplement

ワークフロー実行中に Linear チケットへ進捗・エビデンスを自動同期する。
このスキルは `/feature-dev` や `/debug-flow` から `--linear` フラグ指定時に Read され、各セクションの手順に従って実行される。

## 設計方針

- **記録専用**: Linear は可視化・記録用。ワークフロー本体のデータフローには影響しない
- **ベストエフォート**: Linear API 失敗はワークフローをブロックしない
- **冪等性**: 同じフェーズを2回 sync しても安全

## Activation

`--linear` フラグで有効化。フラグなしの場合、ワークフローはこのスキルを一切参照しない。

有効化時のフロー:
1. ワークフロー開始時: このスキルファイルを Read
2. Phase 1 開始前: `resolve_ticket` セクションに従いチケットを特定
3. チケット特定成功: `sync_workflow_start` を実行
4. 各フェーズ完了後（Audit Gate の後）: `sync_phase` を実行
5. Handover 実行時: `sync_handover` を実行
6. ワークフロー正常完了時: `sync_complete` を実行

## resolve_ticket

### 目的
ワークフローに紐づく Linear チケットを特定し、`linear_ticket_id` を確定する。

### 手順

1. ブランチ名からチケットID を推定:
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```
   結果に対して `/([A-Z]+-\d+)/` で Linear チケットIDを抽出。

2. **推定成功時**: Linear API で存在確認:
   - `mcp__plugin_linear_linear__get_issue(id: 抽出したID)` を実行
   - 取得成功 → ユーザーに提示:
     ```
     Linear チケット {id}: {title} に紐づけますか？
     (y: 確定 / 別のチケットIDを入力 / n: sync なしで続行)
     ```
   - 取得失敗（存在しない）→ 手順3へ

3. **推定失敗時**: 直近のアサイン済みチケットを検索:
   - `mcp__plugin_linear_linear__get_authenticated_user()` で現在ユーザーを取得
   - `mcp__plugin_linear_linear__list_issues(assignee: user_id, state: "In Progress", limit: 5)` で候補取得
   - ユーザーに一覧を提示し選択を求める:
     ```
     紐づける Linear チケットを選んでください:
     1. ABC-123: Auth token expiry bug
     2. ABC-456: Dashboard performance
     3. (IDを直接入力)
     4. (sync なしで続行)
     ```

4. **ユーザーが sync なしを選択**: `linear_ticket_id = null` として sync 機能を無効化。ワークフローは通常通り続行。

5. **チケット確定時**:
   - `linear_ticket_id` をワークフローコンテキストに保持
   - `project-state.json` 生成時に `linear_ticket_id` フィールドとして記録される

## sync_workflow_start

### 前提条件
- `linear_ticket_id` が確定済み

### 手順

1. **チケットステータスを更新**:
   - `mcp__plugin_linear_linear__get_issue(id: linear_ticket_id)` でチケット情報取得し、チームIDを特定
   - `mcp__plugin_linear_linear__list_issue_statuses(team: team_id)` でステータス一覧取得
   - "In Progress" に相当するステータスを特定（type が "started" のもの）
   - `mcp__plugin_linear_linear__save_issue(id: linear_ticket_id, state: in_progress_status_name)` で更新

2. **Workflow Report Document を作成**:
   - `templates/document.md` を Read し、Document 生成仕様を確認
   - 仕様に従い、初期状態の Document コンテンツを生成（全フェーズ Pending）
   - `mcp__plugin_linear_linear__create_document(title: "Workflow Report — {ticket_id}", content: generated_content, issue: linear_ticket_id, icon: "📋")` で作成
   - 返却された Document の ID を `linear_document_id` としてワークフローコンテキストに保持

3. **開始コメントを投稿**:
   - `mcp__plugin_linear_linear__save_comment(issueId: linear_ticket_id, body: start_comment)` で投稿
   - コメント内容:
     ```markdown
     ## Workflow Started

     **Pipeline:** {pipeline_name}
     **Branch:** {branch_name}
     **Started:** {ISO8601 timestamp}
     **Phases:** {total_phases}
     ```

## sync_phase

### 入力: phase_result

ワークフローから以下の構造体を受け取る:

```json
{
  "phase": 4,
  "phase_name": "execute",
  "verdict": "PASS | FAIL | Done | Skipped",
  "summary": "3 files changed, +120 -45",
  "test_results": {
    "passed": 24,
    "failed": 0,
    "coverage": "87%"
  },
  "audit_observations": [
    {
      "criteria_id": "D4-03",
      "severity": "quality",
      "observation": "共通バリデーション抽出を検討",
      "recommendation": "次スプリントで対応"
    }
  ],
  "evidence_files": [
    {
      "path": "/path/to/vrt-diff.png",
      "label": "VRT差分",
      "content_type": "image/png"
    }
  ]
}
```

フィールドの null/未指定は許容。evidence_files が空なら添付スキップ。

### 手順

1. **エビデンスファイルのアップロード**（evidence_files がある場合）:
   - 各ファイルについて:
     - ファイルを Read で読み込む
     - Bash で base64 エンコード: `base64 -i {path}`
     - `mcp__plugin_linear_linear__create_attachment(issue: linear_ticket_id, base64Content: encoded, filename: basename, contentType: content_type, title: label)` でアップロード
     - **失敗時**: warn ログを出力し、エビデンスリストに「(アップロード失敗。ローカル: {path})」を記載。ワークフローは続行。

2. **フェーズ完了コメントを投稿**:
   - `templates/comment.md` を Read し、コメント生成仕様を確認
   - 仕様に従い、phase_result からコメント本文を生成
   - **冪等性チェック**: `mcp__plugin_linear_linear__list_comments(issueId: linear_ticket_id, limit: 10)` で直近コメントを取得
     - `## Phase {N}:` で始まるコメントが存在 → `mcp__plugin_linear_linear__save_comment(id: existing_comment_id, body: new_body)` で更新
     - 存在しない → `mcp__plugin_linear_linear__save_comment(issueId: linear_ticket_id, body: new_body)` で新規投稿

3. **Document を更新**:
   - `templates/document.md` を Read し、Document 生成仕様を確認
   - これまでの全フェーズ結果を反映した Document コンテンツを再生成
   - `mcp__plugin_linear_linear__update_document(id: linear_document_id, content: regenerated_content)` で上書き更新

## sync_handover

### 前提条件
- `linear_ticket_id` が `project-state.json` に記録されている

### 手順

1. **project-state.json をアップロード**:
   - Handover で生成された `project-state.json` を Read
   - Bash で base64 エンコード: `base64 -i {path_to_project_state_json}`
   - `mcp__plugin_linear_linear__create_attachment(issue: linear_ticket_id, base64Content: encoded, filename: "project-state.json", contentType: "application/json", title: "Handover State ({timestamp})")` でアップロード

2. **中断コメントを投稿**:
   - `templates/handover-comment.md` を Read し、コメント生成仕様を確認
   - 仕様に従い、コメント本文を生成
   - `mcp__plugin_linear_linear__save_comment(issueId: linear_ticket_id, body: handover_comment)` で投稿

3. **Document を更新**:
   - 現在の状態（Handover 中）を反映した Document コンテンツを再生成
   - `mcp__plugin_linear_linear__update_document(id: linear_document_id, content: regenerated_content)` で更新

## sync_complete

### 手順

1. **Document を最終更新**:
   - 全フェーズ完了状態の Document コンテンツを再生成（Status: Complete）
   - `mcp__plugin_linear_linear__update_document(id: linear_document_id, content: final_content)` で更新

2. **完了コメントを投稿**:
   ```markdown
   ## Workflow Complete

   **Pipeline:** {pipeline_name}
   **Branch:** {branch_name}
   **Duration:** {start_time} → {end_time}
   **Result:** 全 {total_phases} フェーズ完了
   ```
   - `mcp__plugin_linear_linear__save_comment(issueId: linear_ticket_id, body: complete_comment)` で投稿

3. **チケットステータスを更新**:
   - `mcp__plugin_linear_linear__list_issue_statuses(team: team_id)` でステータス一覧取得
   - "Done" に相当するステータスを特定（type が "completed" のもの）
   - `mcp__plugin_linear_linear__save_issue(id: linear_ticket_id, state: done_status_name)` で更新

## Error Handling

全ての Linear API 呼び出しは以下のポリシーに従う:

1. **API 失敗時**: ユーザーに warning を表示し、ワークフローを続行。sync をスキップ。
   ```
   ⚠ Linear sync: {API名} が失敗しました。ワークフローは続行します。
   Error: {error_message}
   ```

2. **チケット未存在時**: sync 機能を残りのセッションで無効化し、ワークフローを続行。
   ```
   ⚠ Linear sync: チケット {id} が見つかりません。sync を無効化して続行します。
   ```

3. **添付アップロード失敗時**: コメント内にローカルファイルパスを記載し、続行。
   ```
   ⚠ Linear sync: {filename} のアップロードに失敗しました。ローカルパス: {path}
   ```

4. **ワークフローをブロックする操作は一切行わない**。sync は補助機能であり、本体のワークフロー品質ゲートには影響しない。
