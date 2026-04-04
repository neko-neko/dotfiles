---
phase: 5
phase_name: execute
requires_artifacts:
  - implementation_plan
phase_references:
  - references/audit-gate-protocol.md
  - references/inner-loop-protocol.md
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---

## 実行手順

`references/inner-loop-protocol.md` を Read し、以下の3サブステップで実行する。

### Sub-step 1: Impl (TDD)

1. `requires_artifacts` の `implementation_plan` を Read
2. Evidence Plan が存在する場合、Evidence Collection 要件を抽出
3. Skill invoke: `superpowers:subagent-driven-development`
   - 計画書のタスクを分解
   - 各タスクに `feature-implementer` エージェントを起動
   - feature-implementer は TDD で実装（superpowers:test-driven-development 自動注入）

#### --swarm 時

TeamCreate で "impl-{feature}" チームを作成:
- メンバー: feature-implementer x N（タスク数に応じて）

### Sub-step 2: TestEnrich

全タスク完了後、`inner-loop-protocol.md` セクション3の手順に従い実行:

1. テスト拡充コンテキストを構築:
   - requirements_source: `spec_file` + `implementation_plan`（Phase Summary から解決）
   - existing_tests: `git diff --name-only -- tests/ __tests__/ spec/` + impact 範囲の既存テスト
   - implementation: `git diff` の code_changes 範囲
2. `feature-implementer` を継続起動し、テスト拡充コンテキストを注入
3. feature-implementer がトレーサビリティマップ作成 → ギャップ分析 → テスト執筆 → 自己検証を実行

### Sub-step 3: Verify

1. プロジェクトのテスト実行コマンドで全テストスイートを実行
2. lint を実行（変更ファイルのみ）
3. fmt を実行（変更ファイルのみ）
4. 型チェックを実行
5. ALL PASS → Audit Gate へ進む
6. FAIL → `inner-loop-protocol.md` セクション4の Failure Router に従いルーティング

### Inner Loop 制御

- TestEnrich → Verify のループは最大3回
- 超過時は PAUSE（失敗履歴をユーザーに提示）
- 要件の曖昧さ検出時は即 PAUSE

### Evidence Collection

design Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| code_changes | git_range | ブランチ上のコミット |
| test_results | inline | テスト出力 |
| evidence_collection | file | evidence ディレクトリ |

## Phase Summary テンプレート

```yaml
artifacts:
  code_changes:
    type: git_range
    value: "<first_commit>..<last_commit>"
    branch: "<branch_name>"
  test_results:
    type: inline
    value: "<N passed, N failed, coverage N%>"
  evidence_collection:
    type: file
    value: "<evidence ディレクトリパス>"
```
