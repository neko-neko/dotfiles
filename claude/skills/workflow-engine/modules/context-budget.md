---
name: context-budget
description: >-
  コンテキスト予算管理と handover 判定プロトコル。
  残コンテキストと pipeline.yml の設定に基づき handover の要否を判定する。
---

# コンテキスト予算管理プロトコル

フェーズ完了・Phase Summary 生成後に handover の要否を判定する。

## 判定ロジック

1. pipeline.yml phases 内の当該フェーズの `handover` ポリシーを参照
   - 未指定の場合は `settings.default_handover` を使用
2. ポリシーに基づき判定:
   - `always` → 無条件で `/handover` 実行
   - `optional` → `settings.context_budget` と残コンテキストを比較
     - 次フェーズの phase + references 予算が残コンテキストに収まらない場合 → handover
   - `never` → 続行
     - ただし残量が critical 閾値（orchestrator 予算の 50%）を下回った場合は例外的に handover

## context_budget の参照

pipeline.yml の `settings.context_budget` で定義:
- `orchestrator`: SKILL.md + pipeline.yml 用
- `phase`: phases/*.md + done-criteria 用
- `references`: references/*.md + modules 用

## Inner Loop チェックポイント

execute フェーズの Inner Loop 内では、以下のタイミングでコンテキスト予算を評価する:

1. **Sub-step 1 (Impl) 完了時** — 全タスクの実装完了後、TestEnrich 開始前
2. **Failure Router の各 iteration 開始時** — TestEnrich → Verify ループの各回の開始前

チェックポイントで残量が critical 閾値（orchestrator 予算の 50%）を下回った場合:

1. Phase Summary の `inner_loop_state` に現在の状態を記録:
   - `current_substep`: 次に実行すべきサブステップ
   - `impl_progress`: 完了/未完了タスクのリスト
   - `loop_iteration`: 現在のループ回数
   - `failure_history`: 直近の失敗情報
2. Phase Summary の `status` を `in_progress` に設定
3. `/handover` を実行
