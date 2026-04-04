---
phase: 8
phase_name: review
requires_artifacts:
  - code_changes
  - test_results
phase_references: []
invoke_agents:
  - code-review-quality
  - code-review-security
  - code-review-performance
  - code-review-test
  - code-review-ai-antipattern
  - code-review-impact
  - test-review-coverage
  - test-review-quality
  - test-review-design-alignment
phase_flags:
  codex: optional
  e2e: optional
  iterations: optional
  swarm: optional
---

## 実行手順

1. `requires_artifacts` の `code_changes` から git diff 範囲を特定
2. Skill invoke: `/simplify`（1回）
3. Skill invoke: `/code-review`
   - 6観点を並列起動: quality, security, performance, test, ai-antipattern, impact
   - `--codex` 時: Codex companion 追加
   - `--iterations N` 時: N-way Consensus Vote
4. `--e2e` 時: test-review 観点も並列起動
   - 3観点: coverage, quality, design-alignment
   - design_doc を `--design` 引数で自動付与
5. 全 findings を統合、優先度整理
6. ユーザー承認後、修正実行
7. コード修正がある場合 → regate（verification_chain）

### --swarm 時

TeamCreate で "review-{feature}" チームを作成:
- メンバー: code-review-{quality, security, performance, test, ai-antipattern, impact}
- `--e2e` 時: test-review-{coverage, quality, design-alignment} 追加
- simplify も含める

### Re-gate 検知

コード変更が発生した場合（findings 修正など）:
1. `git diff` でコード変更を検知
2. {execute} Audit Gate を full mode で再実行
3. `--doc` 有効時: {doc-audit} Re-gate（lightweight）
4. `--accept` 有効時: {accept-test} Audit Gate 再実行予約
5. `/code-review` 再実行
6. 新たな findings あれば修正 → ループ

## 成果物定義

| 成果物 | 形式 | 保存先 |
|--------|------|--------|
| review_findings | inline | Phase Summary に含める |

## Phase Summary テンプレート

```yaml
artifacts:
  review_findings:
    type: inline
    value: "<total findings, blocker N, quality N, verdict>"
```
