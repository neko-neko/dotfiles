# Doc Audit Agent Checklists

Layer 2 エージェント群のチェックリスト定義。各エージェントの詳細は `~/.claude/agents/` 配下の定義ファイルを参照。

## 共通規約

### 出力フォーマット

全エージェント共通の JSON findings 形式:
- `id`: カテゴリプレフィックス + 連番（DEP-001, COV-001, COH-001, BIZ-001, ARCH-001, README-001, CLAUDE-001）
- `severity`: high / medium / low
- `confidence`: 0.00-1.00（0.80 未満は除外）
- `fix_type`: deps_fix / content_update / new_doc / delete / merge / skip

### フィルタリング

- confidence < 0.80 は除外
- 同一パターン複数件は1件にまとめ（affected_files で列挙）
- Boundary 外の finding は出力しない

### Scope 制御

| エージェント | Scope A（実装影響のみ） | Scope B（全体棚卸し） |
|---|---|---|
| deps-analyzer | git diff 影響範囲 | 全ドキュメント |
| coverage-analyzer | git diff 対象のみ | 全体 |
| coherence-analyzer | git diff 影響範囲 | 全体 |
| business-rule-analyzer | N/A | 全体 |
| architecture-analyzer | N/A | 全体 |
| readme-analyzer | git diff 影響分 | 全体 |
| claude-md-analyzer | git diff 影響分 | 全体 |

## エージェント起動判定

Layer 1 スクリプト結果に基づくスキップ条件:

| 条件 | 判定 |
|------|------|
| broken_deps = 0 かつ undeclared_deps = 0 | deps-analyzer スキップ |
| stale_signals = 0 かつ orphaned_docs = 0 | coherence-analyzer スキップ |
| 知識系4エージェント | 常時起動 |
| coverage-analyzer | 常時起動 |

## --swarm チーム構成

### Exploration Team

```
TeamCreate: doc-audit-exploration-{feature}
├── code-explorer     [入力: git diff 起点のコードフロー]
├── code-architect    [入力: プロジェクト構造 + CLAUDE.md]
└── impact-analyzer   [入力: git diff の逆依存追跡]
```

### Audit Team

```
TeamCreate: doc-audit-{feature}
├── [構造系] deps-analyzer, coverage-analyzer, coherence-analyzer
├── [知識系] business-rule-analyzer, architecture-analyzer, readme-analyzer, claude-md-analyzer
└── 相互検証:
    構造系 → 知識系: deps の発見 → business-rule/architecture が補完
    知識系 → 構造系: architecture が新パターン検出 → coverage が対応 doc 欠落を確認
    知識系内: architecture → claude-md が CLAUDE.md 更新要否を連動
```
