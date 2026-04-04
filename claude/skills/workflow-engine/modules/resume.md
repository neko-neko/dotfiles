---
name: resume
description: >-
  Resume Gate プロトコル。handover state からのパイプライン復帰フローを定義する。
---

# Resume Gate プロトコル

パイプライン起動時の最優先評価。handover state が存在すれば復帰、なければ新規開始。

## 実行手順

1. `.claude/handover/{branch}/` を走査し、`project-state.json` を検索
2. `pipeline` フィールドが現パイプライン名と一致するか確認
3. 一致 → **Resume Mode**:
   - `pipeline.yml` を Read
   - `phase_summaries` から `current_phase` を特定（最初の未完了フェーズ）
   - `current_phase` の Phase Summary から concerns/directives を抽出（target_phase でフィルタ）
   - ユーザー承認を得て `current_phase` から再開
4. 不一致 or 不在 → **New Mode**:
   - pipeline.yml の最初のフェーズから開始
