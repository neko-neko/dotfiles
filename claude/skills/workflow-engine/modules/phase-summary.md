---
name: phase-summary
description: >-
  Phase Summary の生成フォーマットとアーティファクト追跡ルール。
  各フェーズ完了時に構造化サマリーを生成し保存する。
---

# Phase Summary 生成プロトコル

各フェーズ完了時にオーケストレーターが生成する構造化サマリー。

## 保存先

`.claude/handover/{branch}/{fingerprint}/phase-summaries/{phase_id}.yml`

## フォーマット

```yaml
phase_id: <phase_id>
phase_name: <name>
status: completed | failed
timestamp: <ISO8601>
attempt: <N>
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

## アーティファクト型

| type | 解決方法 | 用途 |
|------|---------|------|
| `file` | Read で読み込み | 設計書、計画書、レポート |
| `git_range` | git diff で参照 | コード変更 |
| `inline` | そのまま使用 | 短いテスト結果、メトリクス |

## concerns/directives 伝播ルール

- 各フェーズは concerns と directives を emit できる
- 両者は `target_phase` で送信先を指定
- エンジンは受信フェーズ進入時に `target_phase` でフィルタし注入する
