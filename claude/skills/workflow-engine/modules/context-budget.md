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
