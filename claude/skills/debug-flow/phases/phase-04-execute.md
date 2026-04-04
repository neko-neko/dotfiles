---
phase: 4
phase_name: execute
requires_artifacts:
  - fix_plan
phase_references:
  - references/audit-gate-protocol.md
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---

## 実行手順

1. `requires_artifacts` の `fix_plan` を Read
2. Evidence Plan が存在する場合、Evidence Collection 要件を抽出
3. Skill invoke: `superpowers:subagent-driven-development`
   - 修正対象・根本原因・完了条件・検証方法を self-contained な実装 spec に再構成
   - 各タスクに `feature-implementer` エージェントを起動
   - feature-implementer は TDD で実装（superpowers:test-driven-development 自動注入）

### --swarm 時

TeamCreate で "impl-{bug}" チームを作成:
- メンバー: feature-implementer x N（タスク数に応じて）

### Evidence Collection

Phase 1 Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| code_changes | git_range | ブランチ上のコミット |
| test_results | inline | テスト出力 |

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
```
