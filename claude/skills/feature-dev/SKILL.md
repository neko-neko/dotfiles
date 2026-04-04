---
name: feature-dev
description: >-
  品質ゲート付き開発オーケストレーター。9フェーズで設計→レビュー→計画→レビュー→
  実装→Acceptanceテスト→ドキュメント監査→レビュー→統合を一気通貫で実行する。
  --codex 指定時は全レビューフェーズで Codex を有効化。
  --e2e 指定時は Review フェーズで test-review 観点を有効化。
  --accept 指定時は accept-test フェーズを有効化。
  --doc 指定時は doc-audit フェーズを有効化。
disable-model-invocation: true
user-invocable: true
---

# feature-dev Orchestrator

品質ゲート付き9フェーズ開発パイプライン。

## 起動

### 引数パース

$ARGUMENTS からフラグを抽出:
- `--codex`: 全レビューフェーズで Codex 並列レビュー有効化
- `--e2e`: Review フェーズで test-review 観点を有効化
- `--accept`: accept-test フェーズを有効化
- `--doc`: doc-audit フェーズを有効化
- `--ui`: Review フェーズに UI レビューエージェントを追加
- `--iterations N`: レビューフェーズの N-way 投票回数（デフォルト: 3）
- `--swarm`: 対応フェーズでエージェントチーム化
- `--linear`: Linear チケットへの進捗同期を有効化
- 残りのテキスト: タスク説明

### Resume Gate（最優先評価）

1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
2. `pipeline` フィールドが `"feature-dev"` と一致するか確認
3. 一致 → Resume Mode:
   - `pipeline.yml` を Read
   - `phase_summaries` から `current_phase` を特定
   - `current_phase` の Phase Summary から concerns/directives を抽出（target_phase でフィルタ）
   - ユーザー承認を得て `current_phase` から再開
4. 不一致 or 不在 → New Mode

### New Mode

1. `pipeline.yml` を Read（常時ロード）
2. 最初のフェーズ (design) から開始

## フェーズディスパッチ

各フェーズの実行手順:

1. `pipeline.yml` からカレントフェーズの定義を取得
2. `skip` / `skip_unless` を評価 → スキップ時は次フェーズへ
3. `phase_file` で指定されたファイルを Read（遅延ロード）
4. フロントマターの `requires_artifacts` を Phase Summary チェーンから解決:
   - `type: file` → Read
   - `type: git_range` → git diff で参照
   - `type: inline` → そのまま使用
5. 前フェーズの concerns/directives を `target_phase` でフィルタし注入
6. `phase_references` の参照ファイルを Read
7. `done-criteria` を Read
8. フェーズ実行
9. Audit Gate 実行

## Audit Gate

フェーズ完了後の必須検証（例外なし）:

1. `done-criteria` のフロントマターから `audit` フィールド確認
2. `audit: required` → `phase-auditor` エージェント起動。PASS verdict 必須
3. `audit: lite` → オーケストレーター自身が基準を直接検証

## フェーズ遷移判定

- Audit Gate PASS → Phase Summary 生成 → 次フェーズへ
- Audit Gate FAIL → Regate ディスパッチ

## Phase Summary 生成

各フェーズ完了時に構造化サマリーを生成し保存:

保存先: `.claude/handover/{branch}/{fingerprint}/phase-summaries/phase-{NN}-{name}.yml`

```yaml
phase: N
phase_name: <name>
status: completed | failed
timestamp: <ISO8601>
attempt: N
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

regate_history: []
```

## Regate ディスパッチ

1. `pipeline.yml` の `regate` セクションからトリガー種別を判定
2. `regate/*.md` を Read（該当戦略のみ、遅延ロード）
3. 元フェーズの findings / fail_reasons を Phase Summary から取得
4. fix_instruction を組み立て → rewind_to フェーズに注入
5. `verification_chain` を実行（各フェーズは通常のロード手順）
6. コード変更がない audit_failure → 現フェーズの re-audit のみ

## Handover 判定

フェーズ完了・Phase Summary 生成後:

1. `pipeline.yml` の `handover` ポリシーを参照
2. `always` → `/handover` 実行
3. `optional` → `context_budget` と残コンテキストを比較し判定
4. `never` → 続行（ただし残量が critical 閾値を下回った場合は例外的に handover）

## Linear Sync

`--linear` 有効時、Audit Gate 完了後・次フェーズ遷移前に `/linear-sync` を invoke:
- Phase Summary を sync_phase_summary で Linear に書き込み
- エビデンスを sync_evidence でアップロード
- Handover 時は sync_session でセッション情報を記録
- Regate 時は sync_regate でイベントを記録
