---
title: handover スキーマ拡張 — attempted_approaches フィールド追加
status: approved
date: 2026-03-14
depends-on:
  - claude/skills/handover/SKILL.md
---

# handover スキーマ拡張: attempted_approaches フィールド

## 背景

insights レポート（2026-03-14）で、handover の品質にばらつきがあり、特に**情報不足**が課題として指摘された。再開セッションで同じ失敗アプローチを繰り返すケースがあり、「試みて失敗したこと」が handover に記録されていないことが根本原因。

## 設計

### スキーマ変更

`active_tasks` の各タスクオブジェクトにオプショナルな `attempted_approaches` フィールドを追加する。

```json
{
  "attempted_approaches": [
    {
      "approach": "試みたアプローチの説明",
      "result": "failed | abandoned | partial",
      "reason": "なぜ失敗/断念したか",
      "learnings": "次に活かすべき知見"
    }
  ]
}
```

### result の定義

| 値 | 意味 |
|---|---|
| `failed` | 技術的に試したが失敗した |
| `abandoned` | 実行前に方針転換した |
| `partial` | 部分的に成功したが完全ではない |

### 後方互換性

- バージョンは v3 のまま（破壊的変更なし）
- `attempted_approaches` はオプショナル。既存の handover データはそのまま動作する

### handover.md の表示変更

Remaining セクションの各タスクに `tried:` 行を追加:

```
## Remaining
- [T1] **in_progress** タスク説明
  - files: ファイルパス
  - next: 次のアクション
  - tried: アプローチ説明 → failed: 理由 (知見)
```

### マージルール

同一タスク ID の `attempted_approaches` は追記（重複排除）。

## 変更対象ファイル

- `claude/skills/handover/SKILL.md` — JSON スキーマ定義、handover.md テンプレート、マージルール
- `claude/skills/handover/scripts/fixtures/valid-v3.json` — テストフィクスチャに attempted_approaches を追加
- `claude/skills/handover/scripts/fixtures/mixed-tasks.json` — 同上

## 却下したアプローチ

- **CLAUDE.md にルール追加のみ**: 構造化されないため品質のばらつきが解決しない
- **スキルに品質チェックリスト追加**: スキルを使わないケースに効果がない
- **実装前診断の CLAUDE.md ルール追加**: バグ修正・CI修正は専用スキルでカバー済みのため不要
