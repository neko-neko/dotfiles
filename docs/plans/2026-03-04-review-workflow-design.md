# Review Workflow Design

## Overview

Claude Code のタスク完了後に手動起動（`/review`）する多角的コードレビューワークフロー。
5つの観点を並列エージェントで実行し、統合レポートからユーザー承認を経て修正を行う。

insights 分析に基づく project-agnostic な CLAUDE.md 改善も含む。

## Architecture

### File Layout

```
~/.dotfiles/claude/
├── CLAUDE.md                      # insights由来のルール追加
├── agents/                        # 新規
│   ├── review-quality.md
│   ├── review-security.md
│   ├── review-performance.md
│   └── review-test.md
└── skills/
    └── review/
        └── SKILL.md               # オーケストレーター
```

### Workflow

```
/review [scope]
    │
    ▼
Phase 1: Scope Detection
    │  scope引数に応じてgit diffで対象ファイルを特定
    │
    ▼
Phase 2: Parallel Review（5並列）
    ├─ /simplify invoke
    ├─ review-quality agent
    ├─ review-security agent
    ├─ review-performance agent
    └─ review-test agent
    │
    ▼
Phase 3: Report
    │  統合レポート提示（severity降順）
    │
    ▼
Phase 4: Approve & Fix
    │  ユーザーが対応する指摘を番号で選択
    │  承認された指摘を修正実行
    │
    ▼
Phase 5: Verify
    │  linter・テスト実行で修正を検証
    ▼
  Complete
```

## Phase 1: Scope Detection

```
/review [scope]

scope の解釈:
  (引数なし)     → HEAD~1..HEAD（直近1コミット）
  --branch       → $(git merge-base HEAD main)..HEAD（ブランチ全体）
  --staged       → ステージング済みの変更
  <commit-range> → 任意のgit range（例: abc123..def456）
```

どのスコープでも `git diff <range> --name-only` で対象ファイル一覧を特定し、各エージェントに渡す。

## Phase 2: Parallel Review

### Common Spec

- **入力:** 変更ファイル一覧とその diff 内容
- **出力:** JSON形式の指摘リスト
  ```json
  {
    "findings": [
      {
        "file": "src/api/handler.ts",
        "line": 42,
        "severity": "high",
        "category": "security",
        "description": "ユーザー入力が直接SQLに渡されている",
        "suggestion": "プリペアドステートメントを使用する"
      }
    ]
  }
  ```
- **制約:** 変更範囲のみをレビュー対象とする

### Agent Definitions

| Agent | File | Perspective | Checks |
|-------|------|-------------|--------|
| simplify | 既存プラグイン invoke | コード簡潔性 | 冗長ロジック、不要な抽象化、ネスト深さ、命名明瞭さ |
| review-quality | `agents/review-quality.md` | 品質・パターン適合 | 重複、アンチパターン、規約違反、一貫性 |
| review-security | `agents/review-security.md` | セキュリティ | インジェクション、認証/認可、シークレット漏洩、入力バリデーション |
| review-performance | `agents/review-performance.md` | パフォーマンス・設計 | N+1、再計算、メモリリーク、計算量、アーキテクチャ適合 |
| review-test | `agents/review-test.md` | テスト品質 | カバレッジ漏れ、境界値、エラーケース、flaky risk、整合性 |

### Boundary Rules

- **simplify vs quality:** simplify=「こう書き直すべき」（リファクタ提案）、quality=「規約に違反」（ルール違反指摘）
- **security vs quality:** バリデーション不足（攻撃ベクタあり）→ security、型チェック不足 → quality
- **test:** 他4観点と直交。テストコードとテスト戦略をレビュー。変更実装に対するテスト不足を主に検出

## Phase 3: Report

統合レポートを severity 降順で提示:

```
## Review Report (branch: feature/xxx)
### High
1. [security] src/api/handler.ts:42 — SQLインジェクションの可能性
2. [test] src/api/handler.ts — 新規エンドポイントにテストなし

### Medium
3. [quality] src/models/user.rb:15 — 命名規約違反
4. [performance] src/queries/report.rb:28 — N+1クエリの疑い

### Low
5. [simplify] src/utils/format.ts:10 — ネストしたternaryをif/elseに置換可能

対応する指摘番号を選択してください（例: 1,2,4 / all / none）
```

## Phase 4: Approve & Fix

- ユーザーが番号で選択 → 選択された指摘を修正実行
- `/simplify` 由来の指摘は `/simplify` を再度 invoke して自動修正
- 他のエージェント由来の指摘はオーケストレーターが修正

## Phase 5: Verify

- 修正後に `git diff` で変更確認
- プロジェクトの linter・テストがあれば実行
- 結果を報告して完了

## CLAUDE.md Additions (insights-derived)

### 実装前検証（新規セクション）

- 実装開始前に、関連する依存ライブラリの実際のバージョンと既存コードを確認する
- 前提条件（バージョン、API互換性、プロジェクト状態）をコメントで明示してから実装に入る

### フォーマッタ・リンタのスコープ（新規セクション）

- フォーマッタやリンタは変更したファイルのみに適用する
- `git diff --name-only` で対象を特定し、全体実行しない
