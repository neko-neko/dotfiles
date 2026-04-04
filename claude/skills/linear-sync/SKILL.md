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

## 責務の3層構造

| Layer | 責務 | 状態 |
|-------|------|------|
| Layer 1 | 進捗可視化（フェーズ開始/完了のコメント投稿） | 既存 |
| Layer 2 | コンテキストストア（Phase Summary、エビデンス、regate 履歴の記録） | 新規 |
| Layer 3 | セッション管理（claude resume 用セッション情報、エラー再現性） | 新規 |

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

2. **推定成功時**: Linear でチケット存在を確認:
   - 取得成功 → ユーザーに提示:
     ```
     Linear チケット {id}: {title} に紐づけますか？
     (y: 確定 / 別のチケットIDを入力 / n: sync なしで続行)
     ```
   - 取得失敗（存在しない）→ 手順3へ

3. **推定失敗時**: 直近のアサイン済みチケットを検索:
   - 現在の認証ユーザーを取得
   - アサイン済み In Progress チケットを取得（最大5件）
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

1. **チケットステータスを In Progress に更新**

2. **Workflow Report Document を作成**:
   - `templates/document.md` を Read し、Document 生成仕様を確認
   - 仕様に従い、初期状態の Document コンテンツを生成（全フェーズ Pending）
   - Document を作成し、チケットに紐付ける（タイトル: "Workflow Report — {ticket_id}"、アイコン: 📋）
   - 返却された Document の ID を `linear_document_id` としてワークフローコンテキストに保持

3. **開始コメントを投稿**:
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
   - 各エビデンスファイルをチケットに添付する
   - **失敗時**: warn ログを出力し、エビデンスリストに「(アップロード失敗。ローカル: {path})」を記載。ワークフローは続行。

2. **Phase Summary の記録（Layer 2）**:

   phase_result に加えて Phase Summary を Linear コメントに含める:
   - `artifacts`: 成果物の場所（ファイルパス、ブランチ、コミット範囲）
   - `decisions`: このフェーズで下した設計判断
   - `concerns`: 懸念事項（target_phase 付き）
   - `directives`: 次フェーズへの明示的な指示

   evidence フィールドに基づきエビデンス処理:
   - `linear_sync: inline` → コメント本文に埋め込み
   - `linear_sync: attached` → ファイルをチケットに添付アップロード
   - `linear_sync: reference_only` → ローカルパスのみ記載

3. **フェーズ完了コメントを投稿**:
   - `templates/comment.md` を Read し、コメント生成仕様を確認
   - 仕様に従い、phase_result からコメント本文を生成
   - **冪等性チェック**: 直近コメントを取得し、`## Phase {N}:` で始まるコメントが存在すれば更新、なければ新規投稿

4. **Document を更新**:
   - `templates/document.md` を Read し、Document 生成仕様を確認
   - これまでの全フェーズ結果を反映した Document コンテンツを再生成し、上書き更新

## sync_handover

### 前提条件
- `linear_ticket_id` が `project-state.json` に記録されている

### 手順

1. **project-state.json をアップロード**:
   - project-state.json をチケットに添付する（タイトル: "Handover State ({timestamp})"）

2. **中断コメントを投稿**:
   - `templates/handover-comment.md` を Read し、コメント生成仕様を確認
   - 仕様に従い、コメント本文を生成して投稿

3. **セッション情報の記録（Layer 3）**:

   handover 時に以下のセッション情報をコメントに含める:

   ```yaml
   session:
     session_id: "<CLAUDE_SESSION_ID>"
     started_at: "<ISO8601>"
     ended_at: "<ISO8601>"
     context_usage: "<N%>"
     handover_reason: "policy:always | context:threshold | user:manual"
     resume_command: "claude resume <session_id>"
     phase_at_exit: N
     pending_action: "<次のアクション>"
   ```

4. **Document を更新**:
   - 現在の状態（Handover 中）を反映した Document コンテンツを再生成して更新

## sync_complete

### 手順

1. **Document を最終更新**:
   - 全フェーズ完了状態の Document コンテンツを再生成して更新（Status: Complete）

2. **完了コメントを投稿**:
   ```markdown
   ## Workflow Complete

   **Pipeline:** {pipeline_name}
   **Branch:** {branch_name}
   **Duration:** {start_time} → {end_time}
   **Result:** 全 {total_phases} フェーズ完了
   ```
3. **チケットステータスを Done に更新**

## sync_phase_summary

**目的**: Phase Summary を Linear コメントに書き込む（Layer 2）。

**入力**: Phase Summary YAML（phase-summaries/phase-XX-*.yml の内容）

**手順**:
1. Phase Summary を構造化コメントとして投稿
2. `templates/comment.md` のフォーマットに従い、artifacts/decisions/concerns/directives/evidence を含める
3. 冪等性チェック: 同一フェーズのコメントが既存の場合は更新

**出力**: Linear コメント ID

## sync_session

**目的**: セッション情報を Linear に記録する（Layer 3）。

**入力**:
```yaml
session:
  session_id: "<ID>"
  started_at: "<ISO8601>"
  ended_at: "<ISO8601>"
  context_usage: "<N%>"
  handover_reason: "policy:always | context:threshold | user:manual"
  resume_command: "claude resume <session_id>"
  phase_at_exit: N
  pending_action: "<次のアクション>"
```

**手順**:
1. セッション情報をコメントに含めて投稿
2. Document にセッション履歴を追記

## sync_regate

**目的**: Regate イベントを Linear に記録する（Layer 2）。

**入力**:
```yaml
regate:
  trigger: review_findings | test_failure | audit_failure
  source_phase: <phase_name>
  rewind_to: <phase_name>
  rerun: [<phase_ids>]
  attempt: N
  fix_summary: "<修正内容の要約>"
```

**手順**:
1. Regate イベントをコメントとして投稿（ステータス絵文字付き）
2. Document のフェーズ状態を更新（regate 中表示）

## sync_evidence

**目的**: エビデンスを Linear に記録する（Layer 2）。

**入力**: evidence 配列（Phase Summary の evidence フィールド）

**手順**:
1. `linear_sync: inline` → コメント本文に含める
2. `linear_sync: attached` → ファイルをチケットに添付アップロード、`linear_attachment_id` を返却
3. `linear_sync: reference_only` → ローカルパスのみ記載
4. アップロード失敗時: warn ログ、ローカルパス記載、続行

## read_phase_summary

**目的**: Linear から Phase Summary を読み出す（Layer 2、復元用）。

**入力**: `linear_ticket_id`, `phase_number`

**手順**:
1. チケットのコメント履歴を走査
2. `## Phase {N}:` で始まるコメントを検索
3. コメント内容から Phase Summary YAML を再構成
4. 返却

**用途**: ローカルの phase-summaries/ が不在時のフォールバック復元（continue スキルから呼び出し）。

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
