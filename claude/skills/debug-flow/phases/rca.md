---
phase: 1
phase_name: rca
requires_artifacts: []
phase_references: []
invoke_agents:
  - code-explorer
  - code-architect
  - impact-analyzer
phase_flags:
  swarm: optional
  linear: optional
---

## 実行手順

1. **症状の構造化:** エラーメッセージ、スタックトレース、再現手順を整理
2. **並列探索エージェント起動:**
   - `code-explorer`: 障害箇所のコードフロー（entry point -> データ層）をトレース
   - `code-architect`: 関連するアーキテクチャパターン・制約・暗黙ルールを抽出
   - `impact-analyzer`: 障害箇所からの逆方向依存追跡、副作用リスクの特定
3. **探索結果の統合 -> 根本原因の特定:**
   - 各エージェントの結果を統合し、仮説を立案
   - 1つの仮説を最小変更で検証（max 3 rounds）
   - 仮説棄却時は新仮説を立案（3回失敗でアーキテクチャ問題として PAUSE）
4. **再現テスト作成:** 根本原因を証明する最小再現テスト（failing test）を作成
5. **RCA Report 作成:** 調査結果を構造化文書にまとめる
6. **worktree 作成:** `worktrunk:worktrunk` を invoke し、修正用 worktree とブランチを作成
7. **コミット:** RCA Report と再現テストを worktree 内にコミット

### --swarm 時（Investigation Team）

TeamCreate で "investigation-{bug}" チームを作成:
- メンバー: code-explorer, code-architect, impact-analyzer
- メンバー間通信を有効化: Explorer の発見 -> Architect がパターン分析 -> Impact が依存先を深掘り
- 共有タスク: RCA Report の Investigation Record 各セクションをタスクとして割り当て

### --linear 時

Phase 1 開始前に:
1. `/linear-sync` の `resolve_ticket` セクションを Read し実行
2. チケット確定後、`sync_workflow_start` を実行

### GATE 条件

- 仮説検証3回失敗 -> PAUSE（アーキテクチャ問題エスカレーション）
- 再現テスト作成不可 -> PAUSE（手動再現を提案）
- worktree テスト失敗 -> PAUSE（続行 or STOP をユーザーに提案）

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| rca_report | file | `docs/debug/YYYY-MM-DD-{bug}-rca.md` |
| reproduction_test | file | テストファイル |

## Phase Summary テンプレート

```yaml
artifacts:
  rca_report:
    type: file
    value: "<RCA Report パス>"
  reproduction_test:
    type: file
    value: "<再現テストファイルパス>"
```
