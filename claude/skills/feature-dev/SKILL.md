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

# feature-dev Pipeline

品質ゲート付き9フェーズ開発パイプライン。workflow-engine で駆動される。

## 引数パース

$ARGUMENTS からフラグを抽出:
- `--codex`: 全レビューフェーズで Codex 並列レビュー有効化
- `--e2e`: Review フェーズで test-review 観点を有効化
- `--accept`: accept-test フェーズを有効化
- `--doc`: doc-audit フェーズを有効化
- `--ui`: Review フェーズに UI レビューエージェントを追加
- `--iterations N`: レビューフェーズの N-way 投票回数（デフォルト: 3）
- `--swarm`: 対応フェーズでエージェントチーム化
- `--linear`: Linear インテグレーションを有効化（pipeline.yml の integrations で定義）
- 残りのテキスト: タスク説明

## 実行

1. 上記フラグを JSON にパース: `{"codex": false, "e2e": false, "accept": false, "doc": false, "ui": false, "iterations": 3, "swarm": false, "linear": false}`
2. workflow-engine を invoke:
   ```
   Skill("workflow-engine", "${CLAUDE_SKILL_DIR} {flags_json} {task_description}")
   ```
3. 以降のオーケストレーション（Resume Gate、Phase Dispatch、Audit Gate、Regate、Handover、Integration Hooks）は全て workflow-engine が駆動する。
