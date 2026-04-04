---
phase: 4
phase_name: execute
phase_references: []
invoke_agents:
  - feature-implementer
phase_flags:
  codex: optional
  swarm: optional
---

## 実行手順

inner-loop プロトコル（engine が `uses: [inner-loop]` 経由で注入済み）に従い、Impl → TestEnrich → Verify の3サブステップを実行する。詳細は inner-loop プロトコルを参照。

### Resume 時

inner_loop_state が Phase Summary に存在する場合、inner-loop プロトコルのセクション5「Resume からの再開」に従い、記録されたサブステップから再開する。

### Evidence Collection

rca Audit Gate 完了後に生成された Evidence Plan に基づき:
- テスト coverage
- スクリーンショット/ビデオ（UI 変更時）
- パフォーマンスメトリクス
- セキュリティスキャン結果

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
