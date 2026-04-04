---
name: regate
description: >-
  Regate ディスパッチプロトコル。失敗トリガーの検出、戦略ファイルの適用、
  verification chain の再実行手順を定義する。
---

# Regate ディスパッチプロトコル

Regate は失敗発生時にパイプラインを巻き戻して再実行する仕組みである。

## 実行手順

1. `pipeline.yml` の `regate` セクションからトリガー種別を判定
2. `$PIPELINE_DIR/regate/{strategy_file}` を Read（該当戦略のみ、遅延ロード）
3. 元フェーズの findings / fail_reasons を Phase Summary から取得
4. fix_instruction を組み立て → rewind_to フェーズに注入
5. `verification_chain` を実行（各フェーズは通常のロード手順）
6. コード変更がない audit_failure → 現フェーズの re-audit のみ

## トリガー種別

pipeline.yml の regate セクションにトリガーごとの strategy を定義する。
トリガー名はパイプライン固有に自由定義可能（例: review_findings, test_failure, audit_failure, security_failure）。

各トリガーは以下を持つ:
- `strategy_file`: 戦略ファイルのパス（$PIPELINE_DIR からの相対パス）
- `rewind_to`: 巻き戻し先フェーズ ID（`current` で現フェーズのみ再監査）
- `max_retries`: 最大リトライ回数（省略時は settings.max_phase_retries）
